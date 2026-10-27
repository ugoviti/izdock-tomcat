#!/bin/bash
# Local build of one variant with the versions of versions.env (the same build args as CI).
#
#   tools/build.sh VARIANT [docker build args...]     eg. tools/build.sh 9 --no-cache
#
# VARIANT is the Tomcat major of a TOMCAT<VARIANT>_* block of versions.env (9, 10).
# The image is tagged izdock/tomcat:local-<VARIANT> (override with IMAGE=name:tag).
set -Eeuo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
variant=${1:?usage: tools/build.sh VARIANT [docker build args...]}; shift
# shellcheck source=build/lib.sh
. "$root/build/lib.sh"
load_versions "$root/versions.env"
from=$(variant_image "$variant")
ver="TOMCAT${variant}_VER"
image=${IMAGE:-izdock/tomcat:local-$variant}
echo "building $image from $from"
exec docker build \
  --build-arg IMAGE_FROM="$from" \
  --build-arg APP_VER="${!ver}" \
  --build-arg OS_UPDATE_STAMP="$(date -u +%G-W%V)" \
  --build-arg APP_BUILD_COMMIT="$(git -C "$root" rev-parse --short=7 HEAD 2>/dev/null || echo local)" \
  --build-arg APP_BUILD_DATE="$(date +%s)" \
  -t "$image" "$@" "$root"
