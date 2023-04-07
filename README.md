# Description
Production ready Apache Tomcat Java Servlet Application Server

# Supported tags
- `9.0.X-BUILD`, `9.0.X`, `9.0`, `9`, `latest`
- `8.5.X-BUILD`, `8.5.X`, `8.5`, `8`
- `7.0.X-BUILD`, `7.0.X`, `7.0`, `7`

Where **X** is the patch version number, and **BUILD** is the build number (look into project [Tags](/repository/docker/izdock/tomcat/tags/) page to discover the latest versions)

# Dockerfile
- https://github.com/ugoviti/izdock-tomcat/blob/master/Dockerfile

# Features
- Small image footprint (based on [Linux Debian](/_/debian/) image)
- OpenJDK 11 for Tomcat 9.x
- OpenJDK 1.8 for Tomcat 8.x
- OpenJDK 1.7 for Tomcat 7.x
- APR Native Libraries compiled
- Many customizable variables to use
- Included MySQL Connector 8.x
- Included AS400 Connector 10.x
- GCSFuse support to mount Google Cloud Bucket share
- Using [tini](https://github.com/krallin/tini) as init process

# What is Tomcat?
The Apache Tomcat® software is an open source implementation of the Java Servlet, JavaServer Pages, Java Expression Language and Java WebSocket technologies. The Java Servlet, JavaServer Pages, Java Expression Language and Java WebSocket specifications are developed under the Java Community Process.

The Apache Tomcat software is developed in an open and participatory environment and released under the Apache License version 2. The Apache Tomcat project is intended to be a collaboration of the best-of-breed developers from around the world. We invite you to participate in this open development project. To learn more about getting involved, click here.

Apache Tomcat software powers numerous large-scale, mission-critical web applications across a diverse range of industries and organizations. Some of these users and their stories are listed on the PoweredBy wiki page.

> [wikipedia.org/wiki/Apache_Tomcat](http://en.wikipedia.org/wiki/Apache_Tomcat)

![logo](http://tomcat.apache.org/res/images/tomcat.png)

# How to use this image

```docker pull izdock/tomcat```

```docker run -it --rm izdock/tomcat```

You can test it by visiting http://container-ip:8080 in a browser

If you need access outside the host, on port 8888:
```docker run -it --rm --name tomcat -p 8888:8080 tomcat```

You can then go to http://localhost:8888 or http://host-ip:8888 in a browser.

Ovverride Config Directory:
```docker run -it --rm -p 8080:8080 -e APP_ADMIN_USERNAME=adm.tomcat -e APP_ADMIN_PASSWORD=VeryStrong4ndSecurePWD -e APP_DATA=/data -v /tmp/tomcat:/data --name tomcat izdock/tomcat```

More complex example:
```docker run -it --rm -p 8080:8080 -p 4000:4000  --name tomcat9 -e APP_ADMIN_USERNAME=tomcatadmin -e APP_ADMIN_PASSWORD=VeryStrong4ndSecurePWD -e CATALINA_OPTS="-server -XX:+PrintFlagsFinal -XX:+UnlockExperimentalVMOptions -XX:MaxRAMPercentage=75.0 -XX:MinHeapFreeRatio=25 -XX:MaxHeapFreeRatio=50 -XX:GCTimeRatio=4 -XX:AdaptiveSizePolicyWeight=90 -XX:NewRatio=3 -XX:SurvivorRatio=6 -XX:ReservedCodeCacheSize=320M -XX:+UseCodeCacheFlushing" -e JAVA_OPTS="-Djava.awt.headless=true -Dfile.encoding=UTF-8 -Duser.timezone=Europe/Rome -Duser.language=it -Duser.region=IT -Dorg.apache.catalina.security.SecurityListener.UMASK=0002 -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.port=12345 -XX:-HeapDumpOnOutOfMemoryError -javaagent:/usr/local/tomcat/glowroot/glowroot.jar" izdock/tomcat:9.0.37```

# Environment variables

## generic app configuration variables
```
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
```

## specific app configuration variables
```
ENV JAVA_OPTS     "-Djava.awt.headless=true -XX:+UseG1GC -Dfile.encoding=UTF-8 -server -Xms128m -Xmx512m"
ENV CATALINA_HOME "${APP_HOME}"
ENV PATH          "${PATH}:/opt/jdk/bin:${CATALINA_HOME}/bin"
ENV UMASK         "0002"
```

### Configuration
To customize the configuration just `COPY` your custom configuration in `/opt/tomcat/conf`.

```dockerfile
FROM izdock/tomcat
COPY ./conf /opt/tomcat/conf
```
# Build commands
```
docker build -t tomcat .
```

Or overriding some options:
```
docker build --rm=true --pull=true --build-arg IMAGE_FROM=tomcat:10.1.4-jdk17-temurin-jammy --build-arg APP_VER_MAJOR=10 --build-arg APP_VER_MINOR=1 --build-arg APP_VER_PATCH=4 -f Dockerfile -t izdock/tomcat .
```

# Quick reference

-	**Where to get help**:
	[InitZero Corporate Support](https://www.initzero.it/)

-	**Where to file issues**:
	[https://github.com/ugoviti](https://github.com/ugoviti)

-	**Maintained by**:
	[Ugo Viti](https://github.com/ugoviti)

-	**Supported architectures**:
	[`amd64`]

-	**Supported Docker versions**:
	[the latest release](https://github.com/docker/docker-ce/releases/latest) (down to 1.6 on a best-effort basis)

# License

View [Apache license information](https://www.apache.org/licenses/) and for the software contained in this image.

As with all Docker images, these likely also contain other software which may be under other licenses (such as Bash, etc from the base distribution, along with any direct or indirect dependencies of the primary software being contained).

As for any pre-built image usage, it is the image user's responsibility to ensure that any use of this image complies with any relevant licenses for all software contained within.
