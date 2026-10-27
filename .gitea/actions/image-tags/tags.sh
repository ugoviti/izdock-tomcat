#!/usr/bin/env bash
# Image tags of a version (the scheme of .gitea/actions/image-tags), one full
# reference per line. Environment:
#   IMAGES         image names, newline separated
#   VERSION        9.0.120 | 9.0.120-rc1 | anything else (used as-is)
#   BUILD_NUMBER   optional: adds <version>-<build-number>
#   LATEST         true | false
# Scheme (the same of the old Drone pipelines):
#   9.0.120       -> 9.0.120, 9.0, 9 [, 9.0.120-<build>] [, latest]
#   9.0.120-rc1   -> 9.0.120-rc1 [, 9.0.120-rc1-<build>]   (prerelease: never X.Y, X, latest)
#   ci-test       -> ci-test                               (not semver: as-is, never latest)
set -euo pipefail
: "${IMAGES:?}" "${VERSION:?}"
latest=${LATEST:-false}
tags=("$VERSION")
if [[ "$VERSION" =~ ^v?([0-9]+)\.([0-9]+)\.([0-9]+)(-[0-9A-Za-z.-]+)?$ ]]; then
  ver=${VERSION#v}
  if [ -z "${BASH_REMATCH[4]}" ]; then
    tags=("$ver" "${BASH_REMATCH[1]}.${BASH_REMATCH[2]}" "${BASH_REMATCH[1]}")
  else
    tags=("$ver") latest=false
  fi
  [ -z "${BUILD_NUMBER:-}" ] || tags+=("$ver-$BUILD_NUMBER")
else
  latest=false
fi
[ "$latest" != true ] || tags+=(latest)
while IFS= read -r image; do
  [ -n "$image" ] || continue
  for t in "${tags[@]}"; do printf '%s:%s\n' "$image" "$t"; done
done <<< "$IMAGES"
