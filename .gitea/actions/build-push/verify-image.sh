#!/bin/bash
# verify-image.sh: post-build checks run INSIDE the image, before it is published.
#   docker run -i --rm --entrypoint "" -e TOMCAT_VER_EXPECTED=9.0.120 IMAGE bash -s < verify-image.sh
# The expected jar versions are read from the versions.env shipped in the image.
# Prints one OK/FAIL line per check, exit 1 if any check fails.
set -u

FAIL=0
ok() { echo "OK   $*"; }
ko() { echo "FAIL $*"; FAIL=1; }
has() { if [ -e "$1" ]; then ok "${2:-$1}"; else ko "${2:-$1} missing"; fi; }

versions=/usr/src/tomcat/versions.env
[ -r "$versions" ] || { ko "$versions missing"; exit 1; }
while IFS='=' read -r k v; do
  [[ "$k" =~ ^[A-Z][A-Z0-9_]*$ ]] && export "$k=$v"
done < "$versions"

# Tomcat version: base image, APP_VER and the running server agree with versions.env
expected=${TOMCAT_VER_EXPECTED:-}
[ -n "$expected" ] || ko "TOMCAT_VER_EXPECTED not set"
server=$(version.sh 2>/dev/null | sed -n 's/^Server number: *//p')
if [[ "$server" == "$expected".* || "$server" == "$expected" ]]; then ok "Tomcat $server"; else ko "Tomcat server number '$server', expected $expected"; fi
if [ "${APP_VER:-}" == "$expected" ]; then ok "APP_VER=$APP_VER"; else ko "APP_VER='${APP_VER:-}', expected $expected"; fi

# java and Tomcat Native
if java -version >/dev/null 2>&1; then ok "$(java -version 2>&1 | head -1)"; else ko "java does not run"; fi
if catalina.sh configtest 2>&1 | grep -q 'Loaded Apache Tomcat Native library'; then ok "Tomcat Native loaded"; else ko "Tomcat Native not loaded"; fi

# jars and tools of versions.env (only the enabled plugins)
lib=$CATALINA_HOME/lib
on() { [ "${!1:-0}" = 1 ]; }
on APP_PLUGIN_PGSQL && has "$lib/postgresql-$PGSQL_JDBC_VER.jar"
on APP_PLUGIN_MYSQL && has "$lib/mysql-connector-j-$MYSQL_JDBC_VER.jar"
on APP_PLUGIN_MSSQL && has "$lib/mssql-jdbc-$MSSQL_JDBC_VER.jre11.jar"
on APP_PLUGIN_AS400 && has "$lib/jt400-$AS400_JDBC_VER.jar"
on APP_PLUGIN_GLOWROOT && has "$CATALINA_HOME/glowroot/glowroot.jar"
on APP_PLUGIN_METRO && has "$lib/webservices-rt-$METRO_VER.jar"
on APP_PLUGIN_JAXB && has "$lib/jaxb-impl.jar"
on APP_PLUGIN_REDISSON && has "$lib/redisson-all-$REDISSON_VER.jar" && has "$lib/redisson-tomcat-$TOMCAT_MAJOR-$REDISSON_VER.jar"
on APP_PLUGIN_JAVAMAIL && has "$lib/javax.mail-$JAVAMAIL_VER.jar"
on APP_PLUGIN_JAVAXMAIL_API && has "$lib/javax.mail-api-$JAVAXMAIL_API_VER.jar"
on APP_PLUGIN_JAVAX_ACTIVATION && has "$lib/javax.activation-api-$JAVAX_ACTIVATION_VER.jar"
on APP_PLUGIN_JAKARTA_ACTIVATION && has "$lib/jakarta.activation-$JAKARTA_ACTIVATION_VER.jar"
on APP_PLUGIN_POI && has "$lib/poi-$POI_VER.jar"
has /usr/local/bin/izmysqlsync
has /usr/bin/tini
has /entrypoint.sh

# layout and owner
owner=$(stat -c %U "$CATALINA_HOME/lib")
if [ "$owner" == "${APP_USR:-tomcat}" ]; then ok "$CATALINA_HOME owned by $owner"; else ko "$CATALINA_HOME/lib owned by $owner"; fi
has "$CATALINA_HOME/conf.dist"

exit $FAIL
