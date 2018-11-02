#!/bin/bash
# usage: ./livenessProbeWS.sh /opt/tomcat/webapps WSEcom2 WSEcom2

WADIR="$1" # mandatory
WAPATTERN="$2" # mandatory
WASUBPATH="$3" # optional
BASEURL="http://localhost:8080"
SOAPFILE="livenessProbeWS.xml"
TIMEOUT=3

# chage directory into script directory
cd "${0%/*}"

[ -z "$WADIR" ] && echo "no webapps base directory path specified. exiting..." && exit 1
[ -z "$WAPATTERN" ] && echo "no webapps pattern path specified. exiting..." && exit 1
[ ! -e "$WADIR" ] && echo "the directory $WADIR doesn't exist. exiting..." && exit 1
[ ! -e "$SOAPFILE" ] && echo "the input soap file $SOAPFILE doesn't exist. exiting..." && exit 1

for WEBAPP in ${WADIR}/*
do
  WEBAPP=${WEBAPP%*/}
  WEBAPP=${WEBAPP##*/}
  if [[ "${WEBAPP}" == $WAPATTERN* ]]; then
      URL=${BASEURL}/${WEBAPP}/${WASUBPATH}
      echo "checking URL: ${URL}"
      http_code=$(curl --write-out "%{http_code}\n" --silent --header 'Content-Type: text/xml;charset=UTF-8' --data @"${SOAPFILE}" "${URL}" --connect-timeout $TIMEOUT --output /dev/null)
      [[ $http_code -ne 200 ]] && echo "WARNING: Return code: $http_code" && exit 1
  fi
done

