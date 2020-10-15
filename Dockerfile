ARG IMAGE_FROM=tomcat:8.5.59-jdk8-openjdk-slim-buster

#FROM golang:1.10.3 AS gcsfuse
#RUN apk add --no-cache git
#ENV GOPATH /go
#RUN go get -u github.com/googlecloudplatform/gcsfuse

FROM ${IMAGE_FROM}

MAINTAINER Ugo Viti <ugo.viti@initzero.it>

# default app args used during build step
ARG APP_VER_MAJOR=8
ARG APP_VER_MINOR=5
ARG APP_VER_PATCH=59
# full app version
ARG APP_VER=${APP_VER_MAJOR}.${APP_VER_MINOR}.${APP_VER_PATCH}
ENV APP_VER=${APP_VER}

## FIXME this format is not supported by Dockerfile find an automatic way
#ARG APP_VER=8.5.58
#ENV APP_VER=${APP_VER}
#ENV APP_VER_SHORT="${APP_VER%.*}"
#ENV APP_VER_MAJOR=${APP_VER/.*/}
#ENV APP_VER_MINOR=${APP_VER_SHORT/*./}
#ENV APP_VER_PATCH=${APP_VER/*./}

# components app versions
## https://dev.mysql.com/downloads/connector/j/
ARG MYSQL_CONNECTOR_J=8.0.21

## https://repo1.maven.org/maven2/net/sf/jt400/jt400
ARG AS400_CONNECTOR_J=10.4

## https://github.com/glowroot/glowroot/releases
ARG GLOWROOT_VERSION=0.13.6

## https://javaee.github.io/metro/download - https://maven.java.net/content/repositories/releases/org/glassfish/metro/metro-standalone/
ARG METRO_VERSION=2.4.4

## https://javaee.github.io/jaxb-v2/ - https://repo1.maven.org/maven2/com/sun/xml/bind/jaxb-ri/
ARG JAXB_VERSION=2.3.3

## https://github.com/redisson/redisson/releases
ARG REDISSON_VERSION=3.13.6

# components versions
ENV TOMCAT_VERSION_MAJOR  ${APP_VER_MAJOR}
ENV TOMCAT_VERSION_MINOR  ${APP_VER_MINOR}
ENV TOMCAT_VERSION_PATCH  ${APP_VER_PATCH}
ENV TOMCAT_VERSION        ${APP_VER}
#ENV TOMCAT_NATIVE_VERSION 1.2.19

ENV TINI_VERSION          0.18.0

# debian specific
ENV DEBIAN_FRONTEND       noninteractive

# app plugins enabled
ENV APP_PLUGIN_MYSQL      1
ENV APP_PLUGIN_AS400      1
ENV APP_PLUGIN_GLOWROOT   1
ENV APP_PLUGIN_METRO      1
ENV APP_PLUGIN_JAXB       0
ENV APP_PLUGIN_REDISSON   1

# generic app configuration variables
ENV APP_NAME              "tomcat"
ENV APP_DESCRIPTION       "Tomcat Web Application Server"
ENV APP_HOME              "/usr/local/tomcat"
ENV APP_CONF              ""
ENV APP_DATA              ""
ENV APP_LOGS              ""
ENV APP_TEMP              ""
ENV APP_WORK              ""
ENV APP_HTTP_PORT         8080
ENV APP_AJP_PORT          8009
ENV APP_SHUTDOWN_PORT     8005
ENV APP_REMOTE_MANAGEMENT 1
ENV APP_UID               91
ENV APP_GID               91
ENV APP_USR               "tomcat"
ENV APP_GRP               "tomcat"
ENV APP_ADMIN_USERNAME    "manager"
ENV APP_ADMIN_PASSWORD    ""

# default app configuration variables
ENV APP_RELINK            1
ENV APP_RECONFIG          1
ENV APP_CONF_DEFAULT      "${APP_HOME}/conf"
ENV APP_DATA_DEFAULT      "${APP_HOME}/webapps"
ENV APP_LOGS_DEFAULT      "${APP_HOME}/logs"
ENV APP_TEMP_DEFAULT      "${APP_HOME}/temp"
ENV APP_WORK_DEFAULT      "${APP_HOME}/work"
ENV APP_SHARED_DEFAULT    "${APP_HOME}/shared"

# specific app configuration variables
ENV JAVA_OPTS     "-Djava.awt.headless=true -Dfile.encoding=UTF-8"
#ENV CATALINA_OPTS "-XX:+UseG1GC -Dfile.encoding=UTF-8 -server -XX:MetaspaceSize=512m -XX:MaxMetaspaceSize=512m -Xms512m -Xmx512m"
#ENV CATALINA_OPTS "-XX:+UseG1GC -Dfile.encoding=UTF-8 -server -Xms128m -Xmx512m"
ENV CATALINA_OPTS "-server"
ENV CATALINA_HOME "${APP_HOME}"
ENV PATH          "${PATH}:${CATALINA_HOME}/bin"
ENV UMASK         "0002"

WORKDIR ${CATALINA_HOME}

## install
RUN echo "Building $APP_DESCRIPTION" && \
  echo "TOMCAT_VERSION_MAJOR: ${TOMCAT_VERSION_MAJOR}" && \
  echo "TOMCAT_VERSION_MINOR: ${TOMCAT_VERSION_MINOR}" && \
  echo "TOMCAT_VERSION_PATCH: ${TOMCAT_VERSION_PATCH}" && \
  echo "TOMCAT_VERSION      : ${TOMCAT_VERSION}"

RUN set -xe && \
  apt-get update && apt-get upgrade -y && \
  apt-get install -y --no-install-recommends \
    bash \
    procps \
    net-tools \
    iputils-ping \
    graphviz \
    fontconfig \
    fonts-dejavu \
    tar \
    bzip2 \
    zip \
    unzip \
    file \
    wget \
    curl \
    imagemagick \
    ca-certificates \
    gnupg \
    netcat \
    && \
  # install tini as init container
  if [ $TOMCAT_VERSION \> 8.0.0 ]; then \
      apt-get install -y --no-install-recommends tini; \
    else \
      curl -fSL --connect-timeout 10 http://github.com/krallin/tini/releases/download/v$TINI_VERSION/tini_$TINI_VERSION-amd64.deb -o tini_$TINI_VERSION-amd64.deb && \
      dpkg -i tini_$TINI_VERSION-amd64.deb && \
      rm -f tini_$TINI_VERSION-amd64.deb \
   ;fi && \
  \
  # include misc jars
  cd "${CATALINA_HOME}/lib" && \
  # mysql java connector
  if [ $APP_PLUGIN_MYSQL = 1 ]; then \
     curl -fSL --connect-timeout 10 "http://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-${MYSQL_CONNECTOR_J}.tar.gz" | tar xz --wildcards --strip 1 -C "${CATALINA_HOME}/lib/" "*/mysql-connector-java-${MYSQL_CONNECTOR_J}.jar" \
  ;fi && \
  # jt400 - as400 java connector
  if [ $APP_PLUGIN_AS400 = 1 ]; then \
     curl -fSL --connect-timeout 10 "https://repo1.maven.org/maven2/net/sf/jt400/jt400/${AS400_CONNECTOR_J}/jt400-${AS400_CONNECTOR_J}.jar" -o "jt400-${AS400_CONNECTOR_J}.jar" \
  ;fi &&\
  # glowroot - java vm monitoring
  if [ $APP_PLUGIN_GLOWROOT = 1 ]; then \
     curl -fSL --connect-timeout 10 "https://github.com/glowroot/glowroot/releases/download/v${GLOWROOT_VERSION}/glowroot-${GLOWROOT_VERSION}-dist.zip" -o "/tmp/glowroot-${GLOWROOT_VERSION}-dist.zip" && \
     unzip "/tmp/glowroot-${GLOWROOT_VERSION}-dist.zip" -d "${CATALINA_HOME}/" && \
     echo '{ "web": { "bindAddress": "0.0.0.0" } }' > "${CATALINA_HOME}/glowroot/admin.json" && \
     rm -f "/tmp/glowroot-${GLOWROOT_VERSION}-dist.zip" \
  ;fi && \
  # metro - webservice toolkit
  if [ $APP_PLUGIN_METRO = 1 ]; then \
     for PACKAGE in \
     webservices-api \
     webservices-extra \
     webservices-extra-api \
     webservices-rt \
     webservices-tools \
     ; do \
     curl -fSL --connect-timeout 10 "https://repo1.maven.org/maven2/org/glassfish/metro/${PACKAGE}/${METRO_VERSION}/${PACKAGE}-${METRO_VERSION}.jar" -o "${CATALINA_HOME}/lib/${PACKAGE}-${METRO_VERSION}.jar" \
     ;done \

     #curl -fSL --connect-timeout 10 "https://maven.java.net/content/repositories/releases//org/glassfish/metro/metro-standalone/${METRO_VERSION}/metro-standalone-${METRO_VERSION}.zip" -o "/tmp/metro-standalone-${METRO_VERSION}.zip" && \
     #unzip -j "/tmp/metro-standalone-${METRO_VERSION}.zip" */lib/*.jar -d "${CATALINA_HOME}/lib/" && \
     #rm -f "/tmp/metro-standalone-${METRO_VERSION}.zip" \
  ;fi && \
  # jaxb - Java Architecture for XML Binding
  if [ $APP_PLUGIN_JAXB = 1 ]; then \
     curl -fSL --connect-timeout 10 "https://repo1.maven.org/maven2/com/sun/xml/bind/jaxb-ri/${JAXB_VERSION}/jaxb-ri-${JAXB_VERSION}.zip" -o "/tmp/jaxb-ri-${JAXB_VERSION}.zip" && \
     unzip -j "/tmp/jaxb-ri-${JAXB_VERSION}.zip" */mod/*.jar -d "${CATALINA_HOME}/lib/" && \
     rm -f "/tmp/jaxb-ri-${JAXB_VERSION}.zip" \
  ;fi && \
  # redis session manager
  if [ $APP_PLUGIN_REDISSON = 1 ]; then \
     curl -fSL --connect-timeout 10 "https://repository.sonatype.org/service/local/repositories/central-proxy/content/org/redisson/redisson-all/${REDISSON_VERSION}/redisson-all-${REDISSON_VERSION}.jar" -o "${CATALINA_HOME}/lib/redisson-all-${REDISSON_VERSION}.jar" && \
     curl -fSL --connect-timeout 10 "https://repository.sonatype.org/service/local/repositories/central-proxy/content/org/redisson/redisson-tomcat-${TOMCAT_VERSION_MAJOR}/${REDISSON_VERSION}/redisson-tomcat-${TOMCAT_VERSION_MAJOR}-${REDISSON_VERSION}.jar" -o "${CATALINA_HOME}/lib/redisson-tomcat-${TOMCAT_VERSION_MAJOR}-${REDISSON_VERSION}.jar" \
  ;fi && \
  cd / && \
  # cleanup system
  apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false && \
  rm -rf /var/lib/apt/lists/* /tmp/*


# verify Tomcat Native is working properly
RUN if [ $TOMCAT_VERSION_MAJOR -ge 8 ]; then \
        set -e && \
        nativeLines="$(catalina.sh configtest 2>&1)" && \
        nativeLines="$(echo "$nativeLines" | grep 'Apache Tomcat Native')" && \
        nativeLines="$(echo "$nativeLines" | sort -u)" && \
        if ! echo "$nativeLines" | grep 'INFO: Loaded Apache Tomcat Native library' >&2; then \
                echo >&2 "$nativeLines" && \
                exit 1 \
        ;fi \
    ;fi

# remove unnecessary default components
RUN set -xe && \
 rm -f  ${CATALINA_HOME}/bin/*.bat && \
 rm -rf ${CATALINA_HOME}/webapps/docs && \
 rm -rf ${CATALINA_HOME}/webapps/examples

# alpine user www-data compatibility
#RUN set -x \
#        && addgroup -g 82 -S www-data \
#        && adduser -u 82 -D -S -G www-data www-data

# pre entrypoint management
RUN set -xe && \
  umask $UMASK && \
  groupadd -g "${APP_GID}" "${APP_GRP}" && \
  useradd -d "${CATALINA_HOME}" -u "${APP_UID}" -r -M -s /sbin/nologin -c "$APP_DESCRIPTION" -g "${APP_GRP}" "${APP_USR}" && \
  chown -R "${APP_USR}":"${APP_GRP}" "${CATALINA_HOME}"/ && \
  # custom tomcat path compatibility
  ln -s "${APP_HOME}" /opt/tomcat

# remove unused files
RUN set -xe && \
  # catalina.properties
  sed 's/tomcat.util.scan.StandardJarScanFilter.jarsToSkip=\\/tomcat.util.scan.StandardJarScanFilter.jarsToSkip=\\\nwebservices-*.jar,\\/' -i "${CATALINA_HOME}/conf/catalina.properties" && \
  # disable ssl engine
  sed 's/SSLEngine="on"/SSLEngine="off"/g' -i "${CATALINA_HOME}/conf/server.xml"
  # disable java assistive_technologies to avoid errors like java.awt.AWTError: Assistive Technology not found: org.GNOME.Accessibility.AtkWrapper (not working since tomcat:8.5.42-jdk8-openjdk-slim)
  #sed -e '/^assistive_technologies=/s/^/#/' -i /etc/java-*-openjdk/accessibility.properties && \
  # test: fix infinite dns cache jvm
  #echo "networkaddress.cache.ttl=60" >> /usr/lib/jvm/default-jvm/jre/lib/security/java.security
  
  
# install gcsfuse
#COPY --from=gcsfuse /go/bin/gcsfuse /usr/local/bin/

# exposed ports
EXPOSE 8080/tcp 8009/tcp

# define volumes
VOLUME ${APP_HOME}
#VOLUME ${APP_CONF_DEFAULT}
#VOLUME ${APP_DATA_DEFAULT}
#VOLUME ${APP_LOGS_DEFAULT}
#VOLUME ${APP_TEMP_DEFAULT}
#VOLUME ${APP_WORK_DEFAULT}
#VOLUME ${APP_SHARED_DEFAULT}

# turn on tomcat user
#USER ${APP_USR}

# add files to container
ADD Dockerfile filesystem README.md /

# container pre-entrypoint variables
ENV APP_RUNAS          "true"
ENV MULTISERVICE       "false"
ENV ENTRYPOINT_TINI    "true"
ENV UMASK              0002

## CI args
ARG APP_VER_BUILD
ARG APP_BUILD_COMMIT
ARG APP_BUILD_DATE

# define other build variables
ENV APP_VER_BUILD    "${APP_VER_BUILD}"
ENV APP_BUILD_COMMIT "${APP_BUILD_COMMIT}"
ENV APP_BUILD_DATE   "${APP_BUILD_DATE}"

# start the container process
ENTRYPOINT ["/entrypoint.sh"]
CMD ["catalina.sh run"]
