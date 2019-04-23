ARG image_from=tomcat:8.5.40-jre8-slim

#FROM golang:1.10.3 AS gcsfuse
#RUN apk add --no-cache git
#ENV GOPATH /go
#RUN go get -u github.com/googlecloudplatform/gcsfuse

FROM ${image_from}

MAINTAINER Ugo Viti <ugo.viti@initzero.it>

# external libraries versions
ARG MYSQL_CONNECTOR_J=8.0.15
ARG AS400_CONNECTOR_J=9.8

# default app versions
ARG tag_ver_major=8
ARG tag_ver_minor=5
ARG tag_ver_patch=40
ARG tag_ver=${tag_ver_major}.${tag_ver_minor}.${tag_ver_patch}

# components versions
ENV TOMCAT_VERSION_MAJOR  ${tag_ver_major}
ENV TOMCAT_VERSION_MINOR  ${tag_ver_minor}
ENV TOMCAT_VERSION_PATCH  ${tag_ver_patch}
ENV TOMCAT_VERSION        ${tag_ver}
#ENV TOMCAT_NATIVE_VERSION 1.2.19

# debian specific
ENV TINI_VERSION          0.18.0
ENV DEBIAN_FRONTEND       noninteractive

# app plugins enabled
ENV APP_PLUGIN_MYSQL      1
ENV APP_PLUGIN_AS400      1
ENV APP_PLUGIN_REDISSON   0

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
#ENV JAVA_OPTS     "-Djava.awt.headless=true -XX:+UseG1GC -Dfile.encoding=UTF-8 -server -XX:MetaspaceSize=512m -XX:MaxMetaspaceSize=512m -Xms512m -Xmx512m"
#ENV JAVA_OPTS     "-Djava.awt.headless=true -XX:+UseG1GC -Dfile.encoding=UTF-8 -server -Xms512m -Xmx512m"
ENV JAVA_OPTS     "-Djava.awt.headless=true -XX:+UseG1GC -Dfile.encoding=UTF-8 -server -Xms128m -Xmx512m"
ENV CATALINA_HOME "${APP_HOME}"
ENV PATH          "${PATH}:${CATALINA_HOME}/bin"
ENV UMASK         "0002"

WORKDIR ${CATALINA_HOME}

## install
# tomcat (thanks https://hub.docker.com/r/andreptb/tomcat/)
# other useful urls:
# https://github.com/Unidata/tomcat-docker
ENV APACHE_MIRROR         "https://archive.apache.org/dist"

RUN set -xe \
  && apt-get update && apt-get upgrade -y \
  && apt-get install -y --no-install-recommends \
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
	  file \
	  wget \
    curl \
    imagemagick \
	  ca-certificates \
    gnupg \
#  && gpg --keyserver gnupg.pub --recv-keys \
#        05AB33110949707C93A279E3D3EFE6B686867BA6 \
#        07E48665A34DCAFAE522E5E6266191C37C037D42 \
#        47309207D818FFD8DCD3F83F1931D684307A10A5 \
#        541FBE7D8F78B25E055DDEE13C370389288584E7 \
#        61B832AC2F1C5A90F0F9B00A1C506407564C17A3 \
#        713DA88BE50911535FE716F5208B0AB1D63011C7 \
#        79F7026C690BAA50B92CD8B66A3AD3F4F22C4FED \
#        9BA44C2621385CB966EBA586F72C284D731FABEE \
#        A27677289986DB50844682F8ACB77FC2E86E29AC \
#        A9C5DF4D22E99998D9875A5110C01C5A2F6059E7 \
#        DCFD35E0BF8CA7344752DE8B6FB21E8933C60243 \
#        F3A04C595DB5B6A5F1ECA43E3B7BBB100D811BBE \
#        F7DA48BB64BCB84ECBA7EE6935CD23C10D498E23 \
  && update-ca-certificates \
  # install tini as init container
  && curl -fSL --connect-timeout 10 http://github.com/krallin/tini/releases/download/v$TINI_VERSION/tini_$TINI_VERSION-amd64.deb -o tini_$TINI_VERSION-amd64.deb \
  && dpkg -i tini_$TINI_VERSION-amd64.deb \
  && rm -f tini_$TINI_VERSION-amd64.deb \
#  && wget -q --no-check-certificate "${APACHE_MIRROR}/tomcat/tomcat-${TOMCAT_VERSION_MAJOR}/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz" \
#  && wget -q --no-check-certificate "${APACHE_MIRROR}/tomcat/tomcat-${TOMCAT_VERSION_MAJOR}/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz.asc" \
#  && gpg --verify "apache-tomcat-${TOMCAT_VERSION}.tar.gz.asc" \
#  && tar -xf "apache-tomcat-${TOMCAT_VERSION}.tar.gz" --strip-components=1 \
#  && rm bin/*.bat \
#  && cp -a webapps webapps-dist \
#  && rm "apache-tomcat-${TOMCAT_VERSION}.tar.gz" \
  # include misc jars
  && cd "${CATALINA_HOME}/lib" \
  #&& wget -q "http://central.maven.org/maven2/commons-codec/commons-codec/1.11/commons-codec-1.11.jar" \
  # mysql java connector
  && if [ $APP_PLUGIN_MYSQL = 1 ]; then \
     curl -fSL --connect-timeout 10 "http://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-${MYSQL_CONNECTOR_J}.tar.gz" | tar xz --wildcards --strip 1 -C "${CATALINA_HOME}/lib/" "*/mysql-connector-java-${MYSQL_CONNECTOR_J}.jar" ; \
     fi \
  # as400 java connector
  && if [ $APP_PLUGIN_AS400 = 1 ]; then \
     curl -fSL --connect-timeout 10 "http://central.maven.org/maven2/net/sf/jt400/jt400/${AS400_CONNECTOR_J}/jt400-${AS400_CONNECTOR_J}.jar" -o "jt400-${AS400_CONNECTOR_J}.jar" ; \
     fi \
  # redis session manager
  && if [ $APP_PLUGIN_REDISSON = 1 ]; then \
     curl -fSL --connect-timeout 10 "https://repository.sonatype.org/service/local/repositories/central-proxy/content/org/redisson/redisson-all/3.6.0/redisson-all-3.6.0.jar" -o "redisson-all-3.6.0.jar" \
     && if [ $TOMCAT_VERSION_MAJOR -ge 8 ]; then \
       curl -fSL --connect-timeout 10 "https://repository.sonatype.org/service/local/repositories/central-proxy/content/org/redisson/redisson-tomcat-8/3.6.0/redisson-tomcat-8-3.6.0.jar" -o "redisson-tomcat-8-3.6.0.jar"; \
      else \
       curl -fSL --connect-timeout 10 "https://repository.sonatype.org/service/local/repositories/central-proxy/content/org/redisson/redisson-tomcat-7/3.6.0/redisson-tomcat-7-3.6.0.jar" -o "redisson-tomcat-7-3.6.0.jar"; \
     fi ;\
     fi \
  # tests
  #&& wget -q "http://central.maven.org/maven2/de/ruedigermoeller/fst/2.57/fst-2.57.jar" \
  #&& wget -q "http://central.maven.org/maven2/com/esotericsoftware/kryo/4.0.1/kryo-4.0.1.jar" \
  #&& wget -q "http://central.maven.org/maven2/software/amazon/ion/ion-java/1.1.0/ion-java-1.1.0.jar" \
  #&& wget -q "http://central.maven.org/maven2/com/fasterxml/jackson/core/jackson-core/2.9.4/jackson-core-2.9.4.jar" \
  #&& wget -q "http://central.maven.org/maven2/com/fasterxml/jackson/core/jackson-annotations/2.9.4/jackson-annotations-2.9.4.jar" \
  #&& wget -q "http://central.maven.org/maven2/com/fasterxml/jackson/core/jackson-databind/2.9.4/jackson-databind-2.9.4.jar" \
  #&& wget -q "http://central.maven.org/maven2/com/fasterxml/jackson/dataformat/jackson-dataformat-avro/2.9.4/jackson-dataformat-avro-2.9.4.jar" \
  #&& wget -q "http://central.maven.org/maven2/com/fasterxml/jackson/dataformat/jackson-dataformat-cbor/2.9.4/jackson-dataformat-cbor-2.9.4.jar" \
  #&& wget -q "http://central.maven.org/maven2/com/fasterxml/jackson/dataformat/jackson-dataformat-csv/2.9.4/jackson-dataformat-csv-2.9.4.jar" \
  #&& wget -q "http://central.maven.org/maven2/com/fasterxml/jackson/dataformat/jackson-dataformat-ion/2.9.4/jackson-dataformat-ion-2.9.4.jar" \
  #&& wget -q "http://central.maven.org/maven2/com/fasterxml/jackson/dataformat/jackson-dataformat-properties/2.9.4/jackson-dataformat-properties-2.9.4.jar" \
  #&& wget -q "http://central.maven.org/maven2/com/fasterxml/jackson/dataformat/jackson-dataformat-protobuf/2.9.4/jackson-dataformat-protobuf-2.9.4.jar" \
  #&& wget -q "http://central.maven.org/maven2/com/fasterxml/jackson/dataformat/jackson-dataformat-smile/2.9.4/jackson-dataformat-smile-2.9.4.jar" \
  #&& wget -q "http://central.maven.org/maven2/com/fasterxml/jackson/dataformat/jackson-dataformat-xml/2.9.4/jackson-dataformat-xml-2.9.4.jar" \
  #&& wget -q "http://central.maven.org/maven2/com/fasterxml/jackson/dataformat/jackson-dataformat-yaml/2.9.4/jackson-dataformat-yaml-2.9.4.jar" \
  # redis session manager - test 2
  #&& wget -q "http://central.maven.org/maven2/com/crimsonhexagon/redis-session-manager/2.2.1/redis-session-manager-2.2.1.jar" \
  # redis session manager - test 3
  #&& wget -q http://central.maven.org/maven2/redis/clients/jedis/2.9.0/jedis-2.9.0.jar \
  #&& wget -q http://central.maven.org/maven2/org/apache/commons/commons-pool2/2.5.0/commons-pool2-2.5.0.jar \
  #&& wget -q http://repo.spring.io/libs-release-local/com/gopivotal/manager/redis-store/1.3.6.RELEASE/redis-store-1.3.6.RELEASE.jar \
  # memcached session sharing - test 4
  #&& wget -q http://central.maven.org/maven2/de/javakaffee/msm/memcached-session-manager/2.1.1/memcached-session-manager-2.1.1.jar \
  #&& wget -q http://central.maven.org/maven2/de/javakaffee/msm/memcached-session-manager-tc8/2.1.1/memcached-session-manager-tc8-2.1.1.jar \
  #&& wget -q http://central.maven.org/maven2/de/javakaffee/msm/msm-kryo-serializer/2.1.1/msm-kryo-serializer-2.1.1.jar \
  #&& wget -q http://central.maven.org/maven2/de/javakaffee/kryo-serializers/0.42/kryo-serializers-0.42.jar \
  #&& wget -q http://central.maven.org/maven2/net/spy/spymemcached/2.12.3/spymemcached-2.12.3.jar \
  #&& wget -q http://central.maven.org/maven2/com/esotericsoftware/kryo/4.0.1/kryo-4.0.1.jar \
  #&& wget -q http://central.maven.org/maven2/com/esotericsoftware/minlog/1.3.0/minlog-1.3.0.jar \
  #&& wget -q http://central.maven.org/maven2/com/esotericsoftware/reflectasm/1.11.3/reflectasm-1.11.3.jar \
  #&& wget -q http://central.maven.org/maven2/org/ow2/asm/asm/5.2/asm-5.2.jar \
  #&& wget -q http://central.maven.org/maven2/org/objenesis/objenesis/2.6/objenesis-2.6.jar \
  #&& wget -q http://central.maven.org/maven2/joda-time/joda-time/2.9.9/joda-time-2.9.9.jar \
  #&& wget -q http://central.maven.org/maven2/redis/clients/jedis/2.9.0/jedis-2.9.0.jar \
#  && cd /tmp \
# tomcat apr native support build from source
#  && wget -q --no-check-certificate "${APACHE_MIRROR}/tomcat/tomcat-connectors/native/${TOMCAT_NATIVE_VERSION}/source/tomcat-native-${TOMCAT_NATIVE_VERSION}-src.tar.gz" \
#  && cd /tmp && tar -xf "tomcat-native-${TOMCAT_NATIVE_VERSION}-src.tar.gz" && cd "tomcat-native-${TOMCAT_NATIVE_VERSION}-src/native" \
#  && ./configure --with-java-home="$JAVA_HOME" --with-ssl=no --prefix="$CATALINA_HOME" \
#  && make install \
#  && ln -sv "${CATALINA_HOME}/lib/libtcnative-1.so" "/usr/lib/" && ln -sv "/lib/libz.so.1" "/usr/lib/libz.so.1" \
  && cd / \
  # disable ssl engine
  && sed -i 's/SSLEngine="on"/SSLEngine="off"/g' "${CATALINA_HOME}/conf/server.xml" \
  # disable java assistive_technologies to avoid errors like java.awt.AWTError: Assistive Technology not found: org.GNOME.Accessibility.AtkWrapper
  && sed -e '/^assistive_technologies=/s/^/#/' -i /etc/java-*-openjdk/accessibility.properties \
  # test: fix infinite dns cache jvm
  #&& echo "networkaddress.cache.ttl=60" >> /usr/lib/jvm/default-jvm/jre/lib/security/java.security \
  # cleanup system
  && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
  && rm -rf /var/lib/apt/lists/* /tmp/*


# verify Tomcat Native is working properly
RUN if [ $TOMCAT_VERSION_MAJOR -ge 8 ]; then \
        set -e \
        && nativeLines="$(catalina.sh configtest 2>&1)" \
        && nativeLines="$(echo "$nativeLines" | grep 'Apache Tomcat Native')" \
        && nativeLines="$(echo "$nativeLines" | sort -u)" \
        && if ! echo "$nativeLines" | grep 'INFO: Loaded APR based Apache Tomcat Native library' >&2; then \
                echo >&2 "$nativeLines"; \
                exit 1; \
        fi \
    fi

# remove unnecessary default components
RUN set -xe \
 && rm -f  ${CATALINA_HOME}/bin/*.bat \
 &&	rm -rf ${CATALINA_HOME}/webapps/docs \
 &&	rm -rf ${CATALINA_HOME}/webapps/examples

# alpine user www-data compatibility
#RUN set -x \
#        && addgroup -g 82 -S www-data \
#        && adduser -u 82 -D -S -G www-data www-data

# pre entrypoint management
RUN set -xe \
  && umask $UMASK \
  && groupadd -g "${APP_GID}" "${APP_GRP}" \
  && useradd -d "${CATALINA_HOME}" -u "${APP_UID}" -r -M -s /sbin/nologin -c "$APP_DESCRIPTION" -g "${APP_GRP}" "${APP_USR}" \
  && chown -R "${APP_USR}":"${APP_GRP}" "${CATALINA_HOME}"/ \
  # custom tomcat path compatibility
  && ln -s "${APP_HOME}" /opt/tomcat

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

# set default umask
ENV UMASK           0002

# container pre-entrypoint variables
ENV MULTISERVICE    "false"
ENV ENTRYPOINT_TINI "true"

# add files to container
ADD Dockerfile filesystem VERSION README.md /

# start the container process
ENTRYPOINT ["/entrypoint.sh"]
CMD ["catalina.sh run"]
