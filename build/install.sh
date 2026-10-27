#!/bin/bash
# install.sh: the whole image build, run by the Dockerfile on top of the official tomcat image.
# Versions and sha256 come from versions.env only; APP_PLUGIN_* (Dockerfile ENV) enable each component.
#   APP_VER (build arg, optional)  expected Tomcat version: the build fails if the base image differs
set -Eeuo pipefail

src=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=build/lib.sh
. "$src/build/lib.sh"
load_versions "$src/versions.env"

: "${CATALINA_HOME:?}" "${APP_USR:?}" "${APP_GRP:?}" "${APP_UID:?}" "${APP_GID:?}"
# TOMCAT_MAJOR / TOMCAT_VERSION are set by the official tomcat image
: "${TOMCAT_MAJOR:?not set: the base image is not the official tomcat image}" "${TOMCAT_VERSION:?}"
if [ -n "${APP_VER:-}" ] && [ "$APP_VER" != "$TOMCAT_VERSION" ]; then
  build_die "APP_VER=$APP_VER but the base image is Tomcat $TOMCAT_VERSION: check TOMCAT${TOMCAT_MAJOR}_* in versions.env"
fi

lib="$CATALINA_HOME/lib"
tmp=$(mktemp -d)
enabled() { [ "${!1:-0}" = 1 ]; }
# mvn GROUP ARTIFACT VERSION SHA256: jar from Maven Central into $lib
mvn() { download "$(maven_url "$1" "$2" "$3")" "$4" "$lib/$2-$3.jar"; }

echo "---------- OS packages (OS_UPDATE_STAMP=${OS_UPDATE_STAMP:-none})"
apt-get update
apt-get upgrade -y
apt-get install -y --no-install-recommends \
  bash runit procps net-tools iputils-ping graphviz fontconfig fonts-dejavu \
  tar bzip2 zip unzip file wget curl imagemagick ca-certificates gnupg less \
  netcat-traditional mysql-client-core-8.0 sudo acl openssh-client rsync lftp tini

echo "---------- jars for Tomcat $TOMCAT_VERSION"
if enabled APP_PLUGIN_PGSQL; then
  mvn org.postgresql postgresql "$PGSQL_JDBC_VER" "$PGSQL_JDBC_SHA256"
fi
if enabled APP_PLUGIN_MYSQL; then
  mvn com.mysql mysql-connector-j "$MYSQL_JDBC_VER" "$MYSQL_JDBC_SHA256"
fi
if enabled APP_PLUGIN_MSSQL; then
  mvn com.microsoft.sqlserver mssql-jdbc "$MSSQL_JDBC_VER.jre11" "$MSSQL_JDBC_SHA256"
fi
if enabled APP_PLUGIN_AS400; then
  mvn net.sf.jt400 jt400 "$AS400_JDBC_VER" "$AS400_JDBC_SHA256"
fi
if enabled APP_PLUGIN_GLOWROOT; then
  download "https://github.com/glowroot/glowroot/releases/download/v$GLOWROOT_VER/glowroot-$GLOWROOT_VER-dist.zip" \
    "$GLOWROOT_SHA256" "$tmp/glowroot.zip"
  unzip -q "$tmp/glowroot.zip" -d "$CATALINA_HOME/"
  echo '{ "web": { "bindAddress": "0.0.0.0" } }' > "$CATALINA_HOME/glowroot/admin.json"
fi
if enabled APP_PLUGIN_METRO; then
  for pkg in webservices-api webservices-extra webservices-extra-api webservices-rt webservices-tools; do
    key="METRO_$(tr 'a-z-' 'A-Z_' <<< "${pkg#webservices-}")_SHA256"
    mvn org.glassfish.metro "$pkg" "$METRO_VER" "${!key:-}"
  done
fi
if enabled APP_PLUGIN_JAXB; then
  download "$(maven_url com.sun.xml.bind jaxb-ri "$JAXB_VER" zip)" "$JAXB_SHA256" "$tmp/jaxb-ri.zip"
  unzip -q -j "$tmp/jaxb-ri.zip" '*/mod/*.jar' -d "$lib/"
fi
if enabled APP_PLUGIN_REDISSON; then
  key="REDISSON_TOMCAT${TOMCAT_MAJOR}_SHA256"
  mvn org.redisson redisson-all "$REDISSON_VER" "$REDISSON_SHA256"
  mvn org.redisson "redisson-tomcat-$TOMCAT_MAJOR" "$REDISSON_VER" "${!key:-}"
fi
if enabled APP_PLUGIN_JAVAMAIL; then
  mvn com.sun.mail javax.mail "$JAVAMAIL_VER" "$JAVAMAIL_SHA256"
fi
if enabled APP_PLUGIN_JAVAXMAIL_API; then
  mvn javax.mail javax.mail-api "$JAVAXMAIL_API_VER" "$JAVAXMAIL_API_SHA256"
fi
if enabled APP_PLUGIN_JAVAX_ACTIVATION; then
  mvn javax.activation javax.activation-api "$JAVAX_ACTIVATION_VER" "$JAVAX_ACTIVATION_SHA256"
fi
if enabled APP_PLUGIN_JAKARTA_ACTIVATION; then
  mvn com.sun.activation jakarta.activation "$JAKARTA_ACTIVATION_VER" "$JAKARTA_ACTIVATION_SHA256"
fi
if enabled APP_PLUGIN_POI; then
  mvn org.apache.poi poi "$POI_VER" "$POI_SHA256"
  mvn org.apache.poi poi-ooxml "$POI_VER" "$POI_OOXML_SHA256"
  mvn org.apache.poi poi-excelant "$POI_VER" "$POI_EXCELANT_SHA256"
fi

echo "---------- izmysqlsync $IZMYSQLSYNC_VER"
download "https://github.com/ugoviti/izmysqlsync/archive/$IZMYSQLSYNC_VER.tar.gz" "$IZMYSQLSYNC_SHA256" "$tmp/izmysqlsync.tar.gz"
tar xzf "$tmp/izmysqlsync.tar.gz" --strip-components 1 -C /usr/local/bin/ "izmysqlsync-$IZMYSQLSYNC_VER/izmysqlsync"
chmod 755 /usr/local/bin/izmysqlsync
# no ssh/sshpass in this image
sed 's/COMMANDS=.*/COMMANDS="mysqldump mysql"/' -i /usr/local/bin/izmysqlsync

echo "---------- Tomcat Native"
# same check as the official image: fails the build if libtcnative is not loaded
native=$(catalina.sh configtest 2>&1 | grep 'Apache Tomcat Native' | sort -u || true)
grep 'Loaded Apache Tomcat Native library' <<< "$native" >&2 || { echo "$native" >&2; build_die "Tomcat Native not loaded"; }

echo "---------- layout"
# drop the default components that are not needed, keep a pristine copy of conf
rm -f "$CATALINA_HOME"/bin/*.bat
rm -rf "$CATALINA_HOME/webapps.dist/docs" "$CATALINA_HOME/webapps.dist/examples"
cp -a "$CATALINA_HOME/conf" "$CATALINA_HOME/conf.dist"
mkdir -p "$CATALINA_HOME"/shared/{classes,lib,fonts,conf}
umask "${UMASK:-0002}"
groupadd -g "$APP_GID" "$APP_GRP"
useradd -d "$CATALINA_HOME" -u "$APP_UID" -r -M -s /sbin/nologin -c "${APP_DESCRIPTION:-}" -g "$APP_GRP" "$APP_USR"
chown -R "$APP_USR:$APP_GRP" "$CATALINA_HOME/"
# custom tomcat path compatibility
ln -s "$CATALINA_HOME" /opt/tomcat

echo "---------- cleanup"
apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false
rm -rf /var/lib/apt/lists/* /tmp/* "$tmp" "$src/build"
