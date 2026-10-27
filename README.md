# izdock/tomcat
Production ready Apache Tomcat image: the [official Tomcat image](https://hub.docker.com/_/tomcat)
(Eclipse Temurin JRE, Ubuntu) with JDBC drivers, monitoring and the most used Java libraries
already included, a configurable entrypoint and persistent data management.

# Supported tags
| Tags | Tomcat | Java |
|---|---|---|
| `9.0.X-BUILD`, `9.0.X`, `9.0`, `9`, `latest` | 9.0 | Temurin JRE 11 |
| `10.1.X-BUILD`, `10.1.X`, `10.1`, `10` | 10.1 | Temurin JRE 17 |

**X** is the Tomcat patch version, **BUILD** the build number: see the
[tags page](https://hub.docker.com/r/izdock/tomcat/tags) for the latest ones.
Images are rebuilt every week with the latest OS security updates, so the `X.Y.Z`, `X.Y` and `X`
tags always point to a patched image; `X.Y.Z-BUILD` never changes.

Architecture: `amd64`.

# Features
- Based on the official Tomcat image, with the Apache Tomcat Native (APR) library
- [tini](https://github.com/krallin/tini) as init process, Tomcat running as the unprivileged `tomcat` user
- Admin user and Tomcat Manager configured from environment variables
- Persistent configuration, webapps, logs and shared libraries on any mounted path
- Every included component is pinned and verified by sha256 at build time

## Included components
Installed in `/usr/local/tomcat/lib` (each one can be disabled at build time, see `APP_PLUGIN_*`):

| Component | Use |
|---|---|
| PostgreSQL JDBC driver | PostgreSQL databases |
| MySQL Connector/J | MySQL / MariaDB databases |
| Microsoft JDBC Driver for SQL Server (jre11) | SQL Server databases |
| JTOpen (jt400) | IBM i (AS/400) databases |
| Redisson (`redisson-all` + `redisson-tomcat-<major>`) | HTTP sessions stored in Redis |
| Glowroot (`/usr/local/tomcat/glowroot`) | JVM and application monitoring (APM) |
| Metro web services (`webservices-*`), JAXB RI | SOAP web services, XML binding (javax) |
| JavaMail, javax.mail-api, javax.activation-api, jakarta.activation | mail and activation |
| Apache POI (`poi`, `poi-ooxml`, `poi-excelant`) | Microsoft Office documents |

Metro, JAXB, JavaMail and the activation APIs are the `javax.*` versions, for `javax` applications
(Tomcat 9). Tomcat 10.1 is Jakarta EE (`jakarta.*`): `jakarta` applications bring their own libraries
and do not use them.

Tools: `mysql` / `mysqldump` client, [izmysqlsync](https://github.com/ugoviti/izmysqlsync),
`curl`, `rsync`, `lftp`, `openssh-client`, `imagemagick`, `graphviz`.

The exact versions of every image are listed in
[versions.env](https://github.com/ugoviti/izdock-tomcat/blob/master/versions.env), and inside the
container in `/usr/src/tomcat/versions.env`.

# How to use this image
```
docker run -d --name tomcat -p 8080:8080 izdock/tomcat
```
Then open http://localhost:8080 (or http://host-ip:8080).

On the first start, when `APP_ADMIN_PASSWORD` is not set, a random password is generated for the
admin user and printed in the container log (`docker logs tomcat`).

## Persistent data
Set the paths where configuration, webapps and shared files must live, and mount a volume there.
On the first start the default content is copied into the empty directories:
```
docker run -d --name tomcat -p 8080:8080 \
  -e APP_ADMIN_USERNAME=admin -e APP_ADMIN_PASSWORD=VeryStrong4ndSecurePWD \
  -e APP_CONF=/data/tomcat/conf \
  -e APP_DATA=/data/tomcat/webapps \
  -e APP_SHARED=/data/tomcat/shared \
  -v /srv/tomcat:/data \
  izdock/tomcat:9
```

## Java options and monitoring
`JAVA_OPTS` holds the default JVM options of the image (container aware, UTF-8, headless);
put your own options in `CATALINA_OPTS`. Example with time zone, heap sizing, JMX and the
Glowroot agent (web UI on port 4000):
```
docker run -d --name tomcat -p 8080:8080 -p 4000:4000 \
  -e TZ=Europe/Rome \
  -e CATALINA_OPTS="-XX:MaxRAMPercentage=75.0 -Duser.timezone=Europe/Rome -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=12345 -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=false -javaagent:/usr/local/tomcat/glowroot/glowroot.jar" \
  izdock/tomcat:9
```

## Custom image
```dockerfile
FROM izdock/tomcat:9
COPY ./conf /usr/local/tomcat/conf
COPY ./myapp.war /usr/local/tomcat/webapps/
```
`/opt/tomcat` is a link to `/usr/local/tomcat`.

# Environment variables

## Tomcat and admin user
| Variable | Default | Description |
|---|---|---|
| `APP_ADMIN_USERNAME` | `manager` | user created in `tomcat-users.xml` with the manager and admin roles |
| `APP_ADMIN_PASSWORD` | random | its password; when empty a random one is printed in the log |
| `APP_REMOTE_MANAGEMENT` | `1` | `1` allows the Tomcat Manager from any address, `0` keeps the Tomcat default (localhost only) |
| `JAVA_OPTS` | see the image | default JVM options of the image |
| `CATALINA_OPTS` | | your JVM and Tomcat options |
| `TZ` | `UTC` | container time zone (eg. `Europe/Rome`) |
| `UMASK` | `0002` | umask of the Tomcat process and of the files it creates |

The configuration hooks (admin user, Manager access, connector limits) run only once: when `APP_CONF`
is persistent, a `.initialized` file in it keeps them from running again.

## Persistent directories
Each variable, when set, moves the directory to that path (a symlink from the default path):

| Variable | Default path |
|---|---|
| `APP_CONF` | `/usr/local/tomcat/conf` |
| `APP_DATA` | `/usr/local/tomcat/webapps` |
| `APP_LOGS` | `/usr/local/tomcat/logs` |
| `APP_TEMP` | `/usr/local/tomcat/temp` |
| `APP_WORK` | `/usr/local/tomcat/work` |
| `APP_SHARED` | `/usr/local/tomcat/shared` (`classes`, `lib`, `fonts`, `conf`) |

## Process
| Variable | Default | Description |
|---|---|---|
| `APP_RUNAS` | `true` | run Tomcat as the `tomcat` user (uid/gid `91`) |
| `ENTRYPOINT_TINI` | `true` | run the command through tini |
| `MULTISERVICE` | `false` | `true` starts the runit services of `/etc/service` instead of the command |
| `CMD_OVERRIDE` | | command run instead of the default `catalina.sh run` |

Exposed ports: `8080` (HTTP), `8009` (AJP).

# Build
Every component version and its sha256 is in
[versions.env](https://github.com/ugoviti/izdock-tomcat/blob/master/versions.env), the single source
of truth of the build. One variant per Tomcat major:
```
git clone https://github.com/ugoviti/izdock-tomcat.git && cd izdock-tomcat
tools/build.sh 9        # -> izdock/tomcat:local-9
tools/build.sh 10       # -> izdock/tomcat:local-10
```
To leave out a component, set its `APP_PLUGIN_<NAME>=0` in the Dockerfile.

Check upstream for new versions and update versions.env (versions and sha256):
```
tools/make-updates.sh           # report only
tools/make-updates.sh --apply   # update versions.env, then build and test
```
Every component stays on its major version: a new major is only reported. To keep a component on a
given version add `<NAME>_PIN=<version>` next to its `<NAME>_VER` in versions.env
(eg. `MYSQL_JDBC_PIN=8.2.0`) and run `tools/make-updates.sh --apply`.

# Quick reference
- **Source code and issues**: [github.com/ugoviti/izdock-tomcat](https://github.com/ugoviti/izdock-tomcat)
- **Maintained by**: [Ugo Viti](https://github.com/ugoviti)
- **Support**: [InitZero](https://www.initzero.it/)

# License
Apache Tomcat is released under the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0).

As with all Docker images, this one also contains other software which may be under other licenses
(such as Bash and the other packages of the base distribution, and the included Java libraries).
As for any pre-built image usage, it is the image user's responsibility to ensure that any use of
this image complies with any relevant licenses for all software contained within.
