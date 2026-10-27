#!/bin/bash
# Compare versions.env with upstream and propose updates.
#
#   tools/make-updates.sh [--apply] [--versions FILE]
#
# Prints one line per component of versions.env: current, latest, status
# (ok | UPDATE | unavailable), and for every UPDATE the new KEY=value lines with
# the sha256 of the new files. Every component stays on its major version
# (Tomcat on its X.Y line): a newer major is only shown as a note, change it by hand.
# The base image of each variant is also proposed when its tag was rebuilt
# upstream (same version, new digest: OS/JRE security updates).
# "unavailable" = the upstream lookup failed (eg. GitHub API rate limit).
#
# Pin: a <NAME>_PIN=<version> line in versions.env (for any <NAME>_VER) keeps that
# component on <version>: never moved by an update, proposed (with its sha256)
# when <NAME>_VER differs, also to go back to an older version. Remove the line to unpin.
#
# --apply writes the proposed lines into versions.env (only KEY=value lines
# already present; every value checked, nothing written if one is missing or
# invalid). Then: tools/build.sh 9 && tools/build.sh 10, test, commit.
#
# Exit code: 0 all current (or, with --apply, updates applied), 10 updates
# available, 2 incomplete (lookups unavailable), 1 error. GITHUB_TOKEN
# (optional) raises the GitHub API rate limit (60 requests/hour without it).
# Requires: curl, jq, sha256sum.

set -Eeuo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
versions="$root/versions.env"
apply=''
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) apply=1 ;;
    --versions) versions=${2:?--versions FILE}; shift ;;
    -h|--help) sed -n '2,27p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1 (see --help)" >&2; exit 1 ;;
  esac
  shift
done
command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }
# shellcheck source=build/lib.sh
. "$root/build/lib.sh"
load_versions "$versions"

updates=0
unavailable=0
proposals=()

row() { printf '%-24s %-24s %-24s %s\n' "$1" "$2" "$3" "$4"; }
report() { # component current latest [note]
  local name=$1 cur=$2 new=$3 note=${4:-}
  if [ "$cur" == "$new" ]; then row "$name" "$cur" "$new" "ok${note:+ ($note)}"
  else row "$name" "$cur" "$new" "UPDATE${note:+ ($note)}"; updates=$((updates + 1)); return 1
  fi
}
propose() { proposals+=("$@"); }
# lookup: like report, but an empty "latest" means the upstream lookup failed
lookup() { # component current latest source [note]
  if [ -z "$3" ]; then row "$1" "$2" "?" "unavailable ($4)"; unavailable=$((unavailable + 1)); return 0; fi
  report "$1" "$2" "$3" "${5:-}"
}
# apply_pin NAME: with <NAME>_PIN set, the pinned version replaces the upstream one
# (new) and the note says so (with the newest upstream version when it differs)
apply_pin() {
  local k="${1%_VER}_PIN" up=$new
  [ -n "${!k:-}" ] || return 0
  new=${!k}
  if [ -n "$up" ] && [ "$up" != "$new" ]; then note="pinned, latest $up${note:+, $note}"
  else note="pinned${note:+, $note}"; fi
}
# every request retries transient failures; curl messages only when it fails for good
fetch() {
  local err rc=0
  err=$(mktemp)
  curl -fsSL --proto '=https' --connect-timeout 30 --speed-limit 1024 --speed-time 60 --retry 3 --retry-delay 2 --retry-connrefused "$@" 2>"$err" || rc=$?
  [ "$rc" -eq 0 ] || tail -n 1 "$err" >&2
  rm -f "$err"
  return "$rc"
}
# sha256 of a download; empty when the download fails (never the sha256 of an empty file)
sha_of() { local t; t=$(mktemp); if fetch -o "$t" "$1"; then sha256sum "$t" | cut -d' ' -f1; fi; rm -f "$t"; }

gh_api() { fetch ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} -H 'Accept: application/vnd.github+json' "https://api.github.com/$1"; }
gh_latest_release() { local j; j=$(gh_api "repos/$1/releases/latest") || return 1; jq -r '.tag_name // empty' <<< "$j"; }
gh_latest_tag() { local j; j=$(gh_api "repos/$1/tags?per_page=100") || return 1; jq -r '.[].name' <<< "$j" | grep -E '^v?[0-9]+(\.[0-9]+)*$' | sort -V | tail -1; }

# mvn_latest GROUP ARTIFACT CURRENT [SUFFIX]: sets new (newest stable release on the
# major of CURRENT, empty when the lookup fails) and note (a newer major, if any).
# SUFFIX: a fixed version suffix, eg. ".jre11" for mssql-jdbc (stripped from the result)
mvn_latest() {
  local g=$1 a=$2 cur=$3 sfx=${4:-} xml all top
  new='' note=''
  xml=$(fetch "https://repo1.maven.org/maven2/${g//.//}/$a/maven-metadata.xml") || return 0
  all=$(grep -oE '<version>[^<]+</version>' <<< "$xml" | sed -E 's#</?version>##g' |
        grep -E "^[0-9]+(\.[0-9]+)*${sfx//./\\.}\$" | sed "s/${sfx//./\\.}\$//" | sort -V || true)
  new=$(grep -E "^${cur%%.*}\." <<< "$all" | tail -1 || true)
  top=$(tail -1 <<< "$all")
  if [ -n "$top" ] && [ "${top%%.*}" != "${cur%%.*}" ]; then note="major $top available"; fi
}

# maven COMPONENT_PREFIX GROUP ARTIFACT [SUFFIX]: one jar, <PREFIX>_VER and <PREFIX>_SHA256
maven() {
  local p=$1 g=$2 a=$3 sfx=${4:-} cur
  cur="${p}_VER"; cur=${!cur}
  mvn_latest "$g" "$a" "$cur" "$sfx"
  apply_pin "${p}_VER"
  lookup "${p}_VER" "$cur" "$new" "Maven Central" "$note" ||
    propose "${p}_VER=$new" "${p}_SHA256=$(sha_of "$(maven_url "$g" "$a" "$new$sfx")")"
}

row COMPONENT CURRENT LATEST STATUS

# --- base images: newest <X.Y>.<Z>-<FLAVOR> tag of the official tomcat image, and its digest
hub=https://hub.docker.com/v2/repositories/library/tomcat/tags
mapfile -t variants < <(compgen -v | sed -nE 's/^TOMCAT([0-9]+)_VER$/\1/p' | sort -n)
for v in "${variants[@]}"; do
  kver="TOMCAT${v}_VER" kflavor="TOMCAT${v}_FLAVOR" kdigest="TOMCAT${v}_DIGEST"
  cur=${!kver} flavor=${!kflavor} pinned=${!kdigest} line=${cur%.*}
  new='' digest=''
  if j=$(fetch "$hub?page_size=100&ordering=last_updated&name=-$flavor"); then
    new=$(jq -r '.results[].name' <<< "$j" | grep -E "^${line//./\\.}\.[0-9]+-${flavor}\$" | sed "s/-${flavor}\$//" | sort -V | tail -1 || true)
  fi
  note=''
  apply_pin "$kver"
  if [ -n "$new" ]; then
    digest=$(fetch "$hub/$new-$flavor" | jq -r '.digest // empty' || true)
    [ -n "$digest" ] || new=''
  fi
  if ! lookup "$kver" "$cur" "$new" "Docker Hub" "$flavor${note:+, $note}"; then
    propose "$kver=$new" "$kdigest=$digest"
  elif [ -n "$digest" ]; then
    [ "$digest" == "$pinned" ] && note='' || note="tag $cur-$flavor rebuilt upstream"
    report "$kdigest" "${pinned:7:12}" "${digest:7:12}" "$note" || propose "$kdigest=$digest"
  fi
done

# --- JDBC drivers
maven PGSQL_JDBC org.postgresql postgresql
maven MYSQL_JDBC com.mysql mysql-connector-j
maven MSSQL_JDBC com.microsoft.sqlserver mssql-jdbc .jre11
maven AS400_JDBC net.sf.jt400 jt400

# --- glowroot
new=$(gh_latest_release glowroot/glowroot | sed 's/^v//' || true) note=''
apply_pin GLOWROOT_VER
lookup GLOWROOT_VER "$GLOWROOT_VER" "$new" "GitHub API" "$note" ||
  propose "GLOWROOT_VER=$new" "GLOWROOT_SHA256=$(sha_of "https://github.com/glowroot/glowroot/releases/download/v$new/glowroot-$new-dist.zip")"

# --- metro: five jars, one version
mvn_latest org.glassfish.metro webservices-rt "$METRO_VER"
apply_pin METRO_VER
if ! lookup METRO_VER "$METRO_VER" "$new" "Maven Central" "$note"; then
  propose "METRO_VER=$new"
  for pkg in api extra extra-api rt tools; do
    propose "METRO_$(tr 'a-z-' 'A-Z_' <<< "$pkg")_SHA256=$(sha_of "$(maven_url org.glassfish.metro "webservices-$pkg" "$new")")"
  done
fi

# --- jaxb (zip)
mvn_latest com.sun.xml.bind jaxb-ri "$JAXB_VER"
apply_pin JAXB_VER
lookup JAXB_VER "$JAXB_VER" "$new" "Maven Central" "$note" ||
  propose "JAXB_VER=$new" "JAXB_SHA256=$(sha_of "$(maven_url com.sun.xml.bind jaxb-ri "$new" zip)")"

# --- redisson: redisson-all + one redisson-tomcat-<major> per variant
mvn_latest org.redisson redisson-all "$REDISSON_VER"
apply_pin REDISSON_VER
if ! lookup REDISSON_VER "$REDISSON_VER" "$new" "Maven Central" "$note"; then
  propose "REDISSON_VER=$new" "REDISSON_SHA256=$(sha_of "$(maven_url org.redisson redisson-all "$new")")"
  for v in "${variants[@]}"; do
    propose "REDISSON_TOMCAT${v}_SHA256=$(sha_of "$(maven_url org.redisson "redisson-tomcat-$v" "$new")")"
  done
fi

# --- mail and activation
maven JAVAMAIL com.sun.mail javax.mail
maven JAVAXMAIL_API javax.mail javax.mail-api
maven JAVAX_ACTIVATION javax.activation javax.activation-api
maven JAKARTA_ACTIVATION com.sun.activation jakarta.activation

# --- poi: three jars, one version
mvn_latest org.apache.poi poi "$POI_VER"
apply_pin POI_VER
if ! lookup POI_VER "$POI_VER" "$new" "Maven Central" "$note"; then
  propose "POI_VER=$new" "POI_SHA256=$(sha_of "$(maven_url org.apache.poi poi "$new")")" \
    "POI_OOXML_SHA256=$(sha_of "$(maven_url org.apache.poi poi-ooxml "$new")")" \
    "POI_EXCELANT_SHA256=$(sha_of "$(maven_url org.apache.poi poi-excelant "$new")")"
fi

# --- izmysqlsync
new=$(gh_latest_tag ugoviti/izmysqlsync || true) note=''
apply_pin IZMYSQLSYNC_VER
lookup IZMYSQLSYNC_VER "$IZMYSQLSYNC_VER" "$new" "GitHub API" "$note" ||
  propose "IZMYSQLSYNC_VER=$new" "IZMYSQLSYNC_SHA256=$(sha_of "https://github.com/ugoviti/izmysqlsync/archive/$new.tar.gz")"

echo
[ "$unavailable" -eq 0 ] || echo "$unavailable lookup(s) unavailable: the report is incomplete" >&2
if [ "$updates" -eq 0 ]; then
  [ "$unavailable" -eq 0 ] || exit 2
  echo "all components are current"
  exit 0
fi
echo "$updates update(s) available, proposed versions.env lines:"
printf '  %s\n' "${proposals[@]}"
[ -n "$apply" ] || exit 10

# --- --apply: replace the KEY=value lines, all or nothing
for line in "${proposals[@]}"; do
  k=${line%%=*} v=${line#*=}
  [[ "$k" =~ ^[A-Z0-9_]+$ ]] || { echo "apply: invalid line '$line'" >&2; exit 1; }
  grep -q "^$k=" "$versions" || { echo "apply: $k is not in $versions" >&2; exit 1; }
  [ -n "$v" ] || { echo "apply: $k has no value (upstream lookup failed): nothing written" >&2; exit 1; }
  case "$k" in
    *_SHA256) [[ "$v" =~ ^[0-9a-f]{64}$ ]] || { echo "apply: $k is not a sha256 ('$v'): nothing written" >&2; exit 1; } ;;
    *_DIGEST) [[ "$v" =~ ^sha256:[0-9a-f]{64}$ ]] || { echo "apply: $k is not a digest ('$v'): nothing written" >&2; exit 1; } ;;
  esac
done
out=$(mktemp "$versions.XXXXXX")
awk 'NR == FNR { i = index($0, "="); val[substr($0, 1, i - 1)] = substr($0, i + 1); next }
     !/^#/ && (i = index($0, "=")) > 1 && ((k = substr($0, 1, i - 1)) in val) { print k "=" val[k]; next }
     { print }' <(printf '%s\n' "${proposals[@]}") "$versions" > "$out"
chmod --reference="$versions" "$out"
mv -f "$out" "$versions"
echo
echo "applied ${#proposals[@]} line(s) to $versions"
echo "next: tools/build.sh <variant> for each variant, test, then commit (git diff to review)"
[ "$unavailable" -eq 0 ] || exit 2
exit 0
