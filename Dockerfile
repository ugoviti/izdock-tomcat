# https://tomcat.apache.org/
# https://hub.docker.com/_/tomcat
ARG IMAGE_FROM=tomcat:9.0.97-jre11-temurin-noble

#FROM golang:1.10.3 AS gcsfuse
#RUN apk add --no-cache git
#ENV GOPATH=/go
#RUN go get -u github.com/googlecloudplatform/gcsfuse

FROM ${IMAGE_FROM}

LABEL maintainer="Ugo Viti <u.viti@wearequantico.it>"

### default app args used during build step
#ARG APP_VER_MAJOR=
#ARG APP_VER_MINOR=
#ARG APP_VER_PATCH=

### full app version
#ARG APP_VER=${APP_VER_MAJOR}.${APP_VER_MINOR}.${APP_VER_PATCH}
ARG APP_VER=9.0.97
ENV APP_VER=${APP_VER}

## FIXME this format is not supported by Dockerfile find an automatic way
#ENV APP_VER_SHORT="${APP_VER%.*}"
#ENV APP_VER_MAJOR="${APP_VER%%.*}"
#ENV APP_VER_MINOR="${APP_VER_SHORT##*.}"
#ENV APP_VER_PATCH="${APP_VER##*.}"

## components versions
#ENV TOMCAT_VER_MAJOR=${APP_VER_MAJOR}
#ENV TOMCAT_VER_MINOR=${APP_VER_MINOR}
#ENV TOMCAT_VER_PATCH=${APP_VER_PATCH}
ENV TOMCAT_VER=${APP_VER}
#ENV TOMCAT_NATIVE_VER=1.2.19

## components app versions
## https://github.com/ugoviti/izmysqlsync
ARG IZMYSQLSYNC_VER=2.0.4

# https://github.com/krallin/tini/releases
ENV TINI_VER=0.19.0

## https://jdbc.postgresql.org
ARG PGSQL_JDBC_VER=42.7.4

## https://dev.mysql.com/downloads/connector/j
ARG MYSQL_JDBC_VER=8.2.0

## https://learn.microsoft.com/en-us/sql/connect/jdbc/download-microsoft-jdbc-driver-for-sql-server?view=sql-server-ver15#available-languages
ARG MSSQL_JDBC_VER=12.8.1
## find MSSQL_JDBC_BASEURL downloading download English (United States) version of the tar.gz jdbc driver from the above url of microsoft web site
ENV MSSQL_JDBC_BASEURL=https://download.microsoft.com/download/1e09cdd5-9901-4bbb-bac3-7b36d4058b72/enu

## https://repo1.maven.org/maven2/net/sf/jt400/jt400
ARG AS400_JDBC_VER=20.0.7

## https://github.com/redisson/redisson/releases
ARG REDISSON_VER=3.37.0

## https://github.com/glowroot/glowroot/releases
ARG GLOWROOT_VER=0.14.2

## https://javaee.github.io/metro/download
## https://repo1.maven.org/maven2/org/glassfish/metro/metro-project/
ARG METRO_VER=2.4.9

## https://javaee.github.io/jaxb-v2/
## https://repo1.maven.org/maven2/com/sun/xml/bind/jaxb-ri/
ARG JAXB_VER=2.3.9

## https://javaee.github.io/javamail/
ARG JAVAMAIL_VER=1.6.2

## https://repo1.maven.org/maven2/javax/mail/javax.mail-api/
ARG JAVAXMAIL_API_VER=1.6.2

## https://repo1.maven.org/maven2/javax/activation/javax.activation-api
ARG JAVAX_ACTIVATION_VER=1.2.0

## https://github.com/eclipse-ee4j/jaf/releases
ARG JAKARTA_ACTIVATION_VER=2.0.1

## https://poi.apache.org/download.html
#ARG POI_VER=5.2.3
#ARG POI_VER_DATE=20220909
ARG POI_VER=3.17
ARG POI_VER_DATE=20170915

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

## install
RUN set -xe && \
  : "---------- START build TOMCAT ----------" && \
  # define tomcat versions splitting TOMCAT_VER
  TOMCAT_VER_SHORT="${TOMCAT_VER%.*}" && \
  TOMCAT_VER_MAJOR="${TOMCAT_VER%%.*}" && \
  TOMCAT_VER_MINOR="${TOMCAT_VER_SHORT##*.}" && \
  TOMCAT_VER_PATCH="${TOMCAT_VER##*.}" && \
  \
  apt update && apt upgrade -y && \
  apt install -y --no-install-recommends \
    bash \
    runit \
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
    less \
    netcat-traditional \
    curl \
    mysql-client-core-8.0 \
    sudo \
    acl \
    openssh-client \
    rsync \
    lftp \
    && \
  # install tini as init container
  if [ ${TOMCAT_VER_MAJOR} \> 8 ]; then \
      apt install -y --no-install-recommends tini; \
    else \
      curl -fSL --connect-timeout 10 http://github.com/krallin/tini/releases/download/v$TINI_VER/tini_$TINI_VER-amd64.deb -o tini_$TINI_VER-amd64.deb && \
      dpkg -i tini_$TINI_VER-amd64.deb && \
      rm -f tini_$TINI_VER-amd64.deb \
   ;fi && \
  \
  # include misc jars
  cd "${CATALINA_HOME}/lib" && \
  \
  # postgresql java connector
  if [ $APP_PLUGIN_PGSQL = 1 ]; then \
    curl -fSL --connect-timeout 10 "https://jdbc.postgresql.org/download/postgresql-${PGSQL_JDBC_VER}.jar" -o "${CATALINA_HOME}/lib/postgresql-${PGSQL_JDBC_VER}.jar" ; \
  fi && \
  \
  # mysql java connector
  if [ $APP_PLUGIN_MYSQL = 1 ]; then \
    if [ $MYSQL_JDBC_VER \> 9.0.0 ]; then \
      curl -fSL --connect-timeout 10 "https://cdn.mysql.com/Downloads/Connector-J/mysql-connector-j-${MYSQL_JDBC_VER}.tar.gz" | tar xz --wildcards --strip 1 -C "${CATALINA_HOME}/lib/" "*/mysql-connector-j-${MYSQL_JDBC_VER}.jar"; \
    if [ $MYSQL_JDBC_VER \> 8.2.0 ]; then \
      curl -fSL --connect-timeout 10 "https://downloads.mysql.com/archives/get/p/3/file/mysql-connector-j-${MYSQL_JDBC_VER}.tar.gz" | tar xz --wildcards --strip 1 -C "${CATALINA_HOME}/lib/" "*/mysql-connector-j-${MYSQL_JDBC_VER}.jar"; \
     else \
      curl -fSL --connect-timeout 10 "http://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-${MYSQL_JDBC_VER}.tar.gz" | tar xz --wildcards --strip 1 -C "${CATALINA_HOME}/lib/" "*/mysql-connector-java-${MYSQL_JDBC_VER}.jar"; \
    fi; \
  fi && \
  \
  # mssql java connector
  if [ $APP_PLUGIN_MSSQL = 1 ]; then \
     curl -fSL --connect-timeout 10 "${MSSQL_JDBC_BASEURL}/sqljdbc_${MSSQL_JDBC_VER}.0_enu.tar.gz" | tar xz --wildcards --strip 3 -C "${CATALINA_HOME}/lib/" "*/enu/jars/mssql-jdbc-${MSSQL_JDBC_VER}.jre11.jar" \
  ;fi && \
  \
  # jt400 - as400 java connector
  if [ $APP_PLUGIN_AS400 = 1 ]; then \
     curl -fSL --connect-timeout 10 "https://repo1.maven.org/maven2/net/sf/jt400/jt400/${AS400_JDBC_VER}/jt400-${AS400_JDBC_VER}.jar" -o "jt400-${AS400_JDBC_VER}.jar" \
  ;fi && \
  \
  # glowroot - java vm monitoring
  if [ $APP_PLUGIN_GLOWROOT = 1 ]; then \
     curl -fSL --connect-timeout 10 "https://github.com/glowroot/glowroot/releases/download/v${GLOWROOT_VER}/glowroot-${GLOWROOT_VER}-dist.zip" -o "/tmp/glowroot-${GLOWROOT_VER}-dist.zip" && \
     unzip "/tmp/glowroot-${GLOWROOT_VER}-dist.zip" -d "${CATALINA_HOME}/" && \
     echo '{ "web": { "bindAddress": "0.0.0.0" } }' > "${CATALINA_HOME}/glowroot/admin.json" && \
     rm -f "/tmp/glowroot-${GLOWROOT_VER}-dist.zip" \
  ;fi && \
  \
  # metro - webservice toolkit
  if [ $APP_PLUGIN_METRO = 1 ]; then \
     for PACKAGE in \
     webservices-api \
     webservices-extra \
     webservices-extra-api \
     webservices-rt \
     webservices-tools \
     ; do \
     curl -fSL --connect-timeout 10 "https://repo1.maven.org/maven2/org/glassfish/metro/${PACKAGE}/${METRO_VER}/${PACKAGE}-${METRO_VER}.jar" -o "${CATALINA_HOME}/lib/${PACKAGE}-${METRO_VER}.jar" \
     ;done \
     #curl -fSL --connect-timeout 10 "https://maven.java.net/content/repositories/releases//org/glassfish/metro/metro-standalone/${METRO_VER}/metro-standalone-${METRO_VER}.zip" -o "/tmp/metro-standalone-${METRO_VER}.zip" && \
     #unzip -j "/tmp/metro-standalone-${METRO_VER}.zip" */lib/*.jar -d "${CATALINA_HOME}/lib/" && \
     #rm -f "/tmp/metro-standalone-${METRO_VER}.zip" \
  ;fi && \
  \
  # jaxb - Java Architecture for XML Binding
  if [ $APP_PLUGIN_JAXB = 1 ]; then \
     curl -fSL --connect-timeout 10 "https://repo1.maven.org/maven2/com/sun/xml/bind/jaxb-ri/${JAXB_VER}/jaxb-ri-${JAXB_VER}.zip" -o "/tmp/jaxb-ri-${JAXB_VER}.zip" && \
     unzip -j "/tmp/jaxb-ri-${JAXB_VER}.zip" */mod/*.jar -d "${CATALINA_HOME}/lib/" && \
     rm -f "/tmp/jaxb-ri-${JAXB_VER}.zip" \
  ;fi && \
  \
  # redis session manager
  if [ $APP_PLUGIN_REDISSON = 1 ]; then \
     curl -fSL --connect-timeout 10 "https://repo1.maven.org/maven2/org/redisson/redisson-all/${REDISSON_VER}/redisson-all-${REDISSON_VER}.jar" -o "${CATALINA_HOME}/lib/redisson-all-${REDISSON_VER}.jar" && \
     curl -fSL --connect-timeout 10 "https://repo1.maven.org/maven2/org/redisson/redisson-tomcat-${TOMCAT_VER_MAJOR}/${REDISSON_VER}/redisson-tomcat-${TOMCAT_VER_MAJOR}-${REDISSON_VER}.jar" -o "${CATALINA_HOME}/lib/redisson-tomcat-${TOMCAT_VER_MAJOR}-${REDISSON_VER}.jar" \
  ;fi && \
  \
  # javamail
  if [ $APP_PLUGIN_JAVAMAIL = 1 ]; then \
     curl -fSL --connect-timeout 10 "https://repo1.maven.org/maven2/com/sun/mail/javax.mail/${JAVAMAIL_VER}/javax.mail-${JAVAMAIL_VER}.jar" -o "${CATALINA_HOME}/lib/javax.mail-${JAVAMAIL_VER}.jar" \
  ;fi && \
  \
  # javaxmail api
  if [ $APP_PLUGIN_JAVAXMAIL_API = 1 ]; then \
     curl -fSL --connect-timeout 10 "https://repo1.maven.org/maven2/javax/mail/javax.mail-api/${JAVAXMAIL_API_VER}/javax.mail-api-${JAVAXMAIL_API_VER}.jar" -o "${CATALINA_HOME}/lib/javax.mail-api-${JAVAXMAIL_API_VER}.jar" \
  ;fi && \
  \
  # javax.activation
  if [ $APP_PLUGIN_JAVAX_ACTIVATION = 1 ]; then \
     curl -fSL --connect-timeout 10 "https://repo1.maven.org/maven2/javax/activation/javax.activation-api/${JAVAX_ACTIVATION_VER}/javax.activation-api-${JAVAX_ACTIVATION_VER}.jar" -o "${CATALINA_HOME}/lib/javax.activation-api-${JAVAX_ACTIVATION_VER}.jar" \
  ;fi && \
  \
  # jakarta.activation
  if [ $APP_PLUGIN_JAKARTA_ACTIVATION = 1 ]; then \
     curl -fSL --connect-timeout 10 "https://repo1.maven.org/maven2/com/sun/activation/jakarta.activation/${JAKARTA_ACTIVATION_VER}/jakarta.activation-${JAKARTA_ACTIVATION_VER}.jar" -o "${CATALINA_HOME}/lib/jakarta.activation-${JAKARTA_ACTIVATION_VER}.jar" \
  ;fi && \
  \
  # poi
  # https://archive.apache.org/dist/poi/release/bin/
  if [ $APP_PLUGIN_POI = 1 ]; then \
     curl -fSL --connect-timeout 10 "https://archive.apache.org/dist/poi/release/bin/poi-bin-${POI_VER}-${POI_VER_DATE}.zip" -o "/tmp/poi-bin-${POI_VER}-${POI_VER_DATE}.zip" && \
     unzip -j "/tmp/poi-bin-${POI_VER}-${POI_VER_DATE}.zip" */poi-"${POI_VER}".jar -d "${CATALINA_HOME}/lib/" && \
     unzip -j "/tmp/poi-bin-${POI_VER}-${POI_VER_DATE}.zip" */poi-ooxml-"${POI_VER}".jar -d "${CATALINA_HOME}/lib/" && \
     unzip -j "/tmp/poi-bin-${POI_VER}-${POI_VER_DATE}.zip" */poi-excelant-"${POI_VER}".jar -d "${CATALINA_HOME}/lib/" && \
     rm -f "/tmp/poi-bin-${POI_VER}-${POI_VER_DATE}.zip" \
  ;fi && \
  cd / && \
  \
  # cleanup system
  apt purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false && \
  rm -rf /var/lib/apt/lists/* /tmp/*

# verify Tomcat Native is working properly
RUN if [ ${TOMCAT_VER_MAJOR} -ge 8 ]; then \
        set -e && \
        nativeLines="$(catalina.sh configtest 2>&1)" && \
        nativeLines="$(echo "$nativeLines" | grep 'Apache Tomcat Native')" && \
        nativeLines="$(echo "$nativeLines" | sort -u)" && \
        if ! echo "$nativeLines" | grep 'INFO: Loaded Apache Tomcat Native library' >&2; then \
                echo >&2 "$nativeLines" && \
                exit 1 \
        ;fi \
    ;fi

## install other components
RUN set -xe && \
  : "---------- START install izmysqlsync by InitZero ----------" && \
  cd /usr/src && \
  curl -fSL --connect-timeout 30 https://github.com/ugoviti/izmysqlsync/archive/${IZMYSQLSYNC_VER}.tar.gz | tar xz --strip 1 -C /usr/local/bin/ && \
  chmod 755 /usr/local/bin/izmysqlsync && \
  # fix missing ssh and sshpass options in the tomcat container
  sed 's/COMMANDS=.*/COMMANDS="mysqldump mysql"/' -i /usr/local/bin/izmysqlsync


### pre entrypoint management
RUN set -xe && \
  ## remove unnecessary default components and copy webapps.dist to webapps
  rm -f  ${CATALINA_HOME}/bin/*.bat && \
  rm -rf ${CATALINA_HOME}/webapps.dist/docs && \
  rm -rf ${CATALINA_HOME}/webapps.dist/examples && \
  cp -a  ${CATALINA_HOME}/conf ${CATALINA_HOME}/conf.dist && \
  \
  # create extra directories
  mkdir -p "${CATALINA_HOME}/shared/classes" && \
  mkdir -p "${CATALINA_HOME}/shared/lib" && \
  mkdir -p "${CATALINA_HOME}/shared/fonts" && \
  mkdir -p "${CATALINA_HOME}/shared/conf" && \
  \
  ## create system users and set default permissions
  umask $UMASK && \
  groupadd -g "${APP_GID}" "${APP_GRP}" && \
  useradd -d "${CATALINA_HOME}" -u "${APP_UID}" -r -M -s /sbin/nologin -c "$APP_DESCRIPTION" -g "${APP_GRP}" "${APP_USR}" && \
  chown -R "${APP_USR}":"${APP_GRP}" "${CATALINA_HOME}"/ && \
  ## custom tomcat path compatibility
  ln -s "${CATALINA_HOME}" /opt/tomcat

## install gcsfuse
#COPY --from=gcsfuse /go/bin/gcsfuse /usr/local/bin/

## exposed ports
EXPOSE 8080/tcp 8009/tcp

## define volumes
#VOLUME ${APP_HOME}

## turn on tomcat user
#USER ${APP_USR}

## add files to container
ADD Dockerfile filesystem README.md /

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
ENV UMASK=0002

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
