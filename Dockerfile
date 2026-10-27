# syntax=docker/dockerfile:1
# check=skip=InvalidDefaultArgInFrom,SecretsUsedInArgOrEnv
# (IMAGE_FROM is always passed, no default on purpose; APP_ADMIN_PASSWORD is empty, set at runtime)
# izdock/tomcat: the official Apache Tomcat image + JDBC drivers, monitoring and tools.
# https://tomcat.apache.org/  -  https://hub.docker.com/_/tomcat
#
# Versions and sha256: versions.env (single source of truth). Build logic: build/install.sh.
# IMAGE_FROM has no default: it comes from versions.env (one variant per Tomcat major).
#   tools/build.sh 9        local build of the Tomcat 9 variant (or 10)
# CI: .gitea/workflows/build.yml

ARG IMAGE_FROM
FROM ${IMAGE_FROM}
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

LABEL maintainer="Ugo Viti <u.viti@wearequantico.it>"

## debian specific
ENV DEBIAN_FRONTEND=noninteractive

## app plugins enabled
ENV APP_PLUGIN_PGSQL=1
ENV APP_PLUGIN_MYSQL=1
ENV APP_PLUGIN_MSSQL=1
ENV APP_PLUGIN_AS400=1
ENV APP_PLUGIN_GLOWROOT=1
ENV APP_PLUGIN_METRO=1
ENV APP_PLUGIN_JAXB=1
ENV APP_PLUGIN_REDISSON=1
ENV APP_PLUGIN_JAVAMAIL=1
ENV APP_PLUGIN_JAVAXMAIL_API=1
ENV APP_PLUGIN_JAVAX_ACTIVATION=1
ENV APP_PLUGIN_JAKARTA_ACTIVATION=1
ENV APP_PLUGIN_POI=1

# generic app configuration variables
ENV APP_NAME="tomcat"
ENV APP_DESCRIPTION="Tomcat Web Application Server"
ENV APP_HOME="/usr/local/tomcat"
ENV APP_CONF=""
ENV APP_DATA=""
ENV APP_LOGS=""
ENV APP_TEMP=""
ENV APP_WORK=""
ENV APP_SHARED=""
ENV APP_HTTP_PORT=8080
ENV APP_AJP_PORT=8009
ENV APP_SHUTDOWN_PORT=8005
ENV APP_REMOTE_MANAGEMENT=1
ENV APP_UID=91
ENV APP_GID=91
ENV APP_USR="tomcat"
ENV APP_GRP="tomcat"
ENV APP_ADMIN_USERNAME="manager"
ENV APP_ADMIN_PASSWORD=""

## app specific variables
ENV CATALINA_HOME="${APP_HOME}"
ENV PATH="${PATH}:${CATALINA_HOME}/bin"
ENV UMASK="0002"

## define workdir
WORKDIR ${CATALINA_HOME}

## install: OS packages, jars, izmysqlsync, layout (build/install.sh)
# APP_VER (optional): expected Tomcat version, the build fails if the base image differs
ARG APP_VER=""
# OS_UPDATE_STAMP: changes every week in CI, so the cached OS upgrade layer is rebuilt
ARG OS_UPDATE_STAMP=""
COPY versions.env /usr/src/tomcat/versions.env
COPY build/ /usr/src/tomcat/build/
RUN /usr/src/tomcat/build/install.sh

## the Tomcat version comes from the base image (TOMCAT_VERSION of the official image)
ENV APP_VER="${TOMCAT_VERSION}"
ENV TOMCAT_VER="${TOMCAT_VERSION}"

## exposed ports
EXPOSE 8080/tcp 8009/tcp

## add files to container
COPY Dockerfile filesystem README.md /

# app specific variables
ENV JAVA_OPTS="-Djava.awt.headless=true -Dfile.encoding=UTF-8 -Dorg.apache.catalina.security.SecurityListener.UMASK=0002 -XshowSettings:vm -XX:-HeapDumpOnOutOfMemoryError -XX:+ExitOnOutOfMemoryError -XX:+UnlockExperimentalVMOptions -XX:+UseContainerSupport -XX:+PreferContainerQuotaForCPUCount -XX:+UseCodeCacheFlushing -XX:+UseStringDeduplication -XX:+OptimizeStringConcat"
## for jmx support add
#ENV JAVA_OPTS="-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.port=12345"
## for changing GarbageCollector and memory constraints
#ENV JAVA_OPTS="-XX:+UseG1GC -XX:MetaspaceSize=512m -XX:MaxMetaspaceSize=512m -Xms512m -Xmx512m"
## for definig tomcat's extra args use CATALINA_OPTS var
#ENV CATALINA_OPTS="-javaagent:$CATALINA_HOME/glowroot/glowroot.jar"

## container pre-entrypoint variables
ENV APP_RUNAS="true"
ENV MULTISERVICE="false"
ENV ENTRYPOINT_TINI="true"

## CI args
ARG APP_VER_BUILD
ARG APP_BUILD_COMMIT
ARG APP_BUILD_DATE

## define other build variables
ENV APP_VER_BUILD="${APP_VER_BUILD}"
ENV APP_BUILD_COMMIT="${APP_BUILD_COMMIT}"
ENV APP_BUILD_DATE="${APP_BUILD_DATE}"

## start the entrypoint process
ENTRYPOINT ["/entrypoint.sh"]
CMD ["catalina.sh run"]
