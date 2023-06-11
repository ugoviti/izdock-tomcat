#!/bin/bash

# enable script debug
#set -x

## entrypoint env management
: ${APP_NAME:=""}
: ${APP_DESCRIPTION:=""}
: ${APP_CHART:=""}
: ${APP_RELEASE:=""}
: ${APP_NAMESPACE:=""}
: ${APP_RECONFIG:=0}
: ${UMASK:=0002} # (**0002**) default umask when creating new files

# override default data directory used by this apps (used for stateful and persistent data)
: ${APP_CONF:=""}
: ${APP_DATA:=""}
: ${APP_LOGS:=""}
: ${APP_TEMP:=""}
: ${APP_WORK:=""}
: ${APP_SHARED:=""}

# array of custom data directory
declare -A appDataDirsCustom=(
  [APP_CONF]="${APP_CONF}"
  [APP_DATA]="${APP_DATA}"
  [APP_LOGS]="${APP_LOGS}"
  [APP_TEMP]="${APP_TEMP}"
  [APP_WORK]="${APP_WORK}"
  [APP_SHARED]="${APP_SHARED}"
)

# array of default default data directory paths used by this app
declare -A appDataDirsDefault=(
  [APP_HOME]="/usr/local/tomcat"
  [APP_CONF]="/usr/local/tomcat/conf"
  [APP_DATA]="/usr/local/tomcat/webapps"
  [APP_LOGS]="/usr/local/tomcat/logs"
  [APP_TEMP]="/usr/local/tomcat/temp"
  [APP_WORK]="/usr/local/tomcat/work"
  [APP_SHARED]="/usr/local/tomcat/shared"
)

# timezone management workaround
: ${TZ:="UTC"}
[ -e "/etc/localtime" ] && rm -f /etc/localtime
[ -e "/etc/timezone" ] && rm -f /etc/timezone
ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
echo "$TZ" > /etc/timezone

# input: arg1 arg2 arg3
# arg1: <ARRAY_NAME> define the array name containing all custom directory paths
# arg2: <ARRAY_NAME> define the array name containing all default directory paths
# arg3: <yes/no> yes = create the Parents full path of default path using the persistent data path as basedir. no or no value = use the persistent data path directly as final data destination
manageDataDir() {
  # arg1: import default dir array name (dirsDefault is an Associative Array)
  # clone the source array into a new temporary array
  dirsDefaultArray="$1"
  eval dirsDefaultIndexs=\${!$1[*]}
  declare -A dirsDefault
  for i in $dirsDefaultIndexs; do
    eval dirsDefault[$i]=\${$1[$i]}
  done
  shift

  # arg2: import custom dir variable name
  dirsCustomArray="$1"
  eval dirsCustomIndexs=\${!$1[*]}
  declare -A dirsCustom
  for i in $dirsCustomIndexs; do
    eval dirsCustom[$i]=\${$1[$i]}
  done
  shift

  # arg3: define if the custom dir must contain parents full path of default dir
  eval makeParents="\$$1"
  shift

  local n=1 ; local t=$(echo ${#dirsCustom[@]})
  for dirCustomIndex in ${!dirsCustom[@]}; do
    #set -x
    local dirCustomStep=${dirsCustom[$dirCustomIndex]}
    local dirDefaultStep=${dirsDefault[$dirCustomIndex]}
    # make partents directories if required
    [[ ! -z "${makeParents}" && "${makeParents}" = "yes" ]] && dirCustomStep="${dirCustomStep}${dirDefaultStep}"
    symlinkDir "${dirDefaultStep}" "${dirCustomStep}" "$(printf '[%02d/%d]' $n $t)"
    # make initialized only on sucessfull directory symlinking
    [ $? = 0 ] && initizializeDir "${dirDefaultStep}".dist "${dirCustomStep}" "$(printf '[%02d/%d]' $n $t)"
    let n+=1
  done
  #set +x
}


## entrypoint functions
runHooks() {
  echo "==> Running Data Management Hooks:"
  # tomcat webapps.dist workaround: copy default data files if the destination data dir is empty
  if [ -e "${appDataDirsDefault[APP_DATA]}.dist" ] && dirEmpty "${appDataDirsDefault[APP_DATA]}" ;then
    mv "${appDataDirsDefault[APP_DATA]}".dist/* "${appDataDirsDefault[APP_DATA]}"/
    rmdir "${appDataDirsDefault[APP_DATA]}".dist
  fi

  manageDataDir appDataDirsDefault appDataDirsCustom no

  # tomcat conf dir management
  if [ ! -f "${appDataDirsDefault[APP_CONF]}/.initialized" ]; then
      tomcatConf
    else
      echo "==> Skipping Configuration Hooks: Detected $APP_NAME configurations already initialized into '${appDataDirsDefault[APP_CONF]}'"
  fi
}


# entrypoint hooks
tomcatConf() {
  echo "==> Running Configuration Hooks:"
  PASSWORD_TYPE=$( [ ${APP_ADMIN_PASSWORD} ] && echo "preset" || echo "random" )

  APP_ADMIN_USERNAME="${APP_ADMIN_USERNAME:-manager}"
  APP_ADMIN_PASSWORD="${APP_ADMIN_PASSWORD:-$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ; echo '')}"

  # use the env variables to make initial configuration changes before starting for the first time
  APP_REMOTE_MANAGEMENT="${APP_REMOTE_MANAGEMENT:-0}"

  echo "---> setting default system umask to $UMASK "
  # set default umask
  export UMASK
  umask $UMASK
  sed "s/^UMASK.*/UMASK $UMASK/" -i /etc/login.defs


  if [ $APP_REMOTE_MANAGEMENT = 1 ]; then
    echo "---> configuring Tomcat Manager access"
    # 1. Catalina/localhost/manager.xml (allow remote management)
#    mkdir -p "${appDataDirsDefault[APP_CONF]}/Catalina/localhost"
#    cat <<EOF > "${appDataDirsDefault[APP_CONF]}/Catalina/localhost/manager.xml"
# <Context privileged="true" antiResourceLocking="false" docBase="\${catalina.home}/webapps/manager">
#   <Valve className="org.apache.catalina.valves.RemoteAddrValve" allow="^.*$" />
#   <Manager sessionAttributeValueClassNameFilter="java\.lang\.(?:Boolean|Integer|Long|Number|String)|org\.apache\.catalina\.filters\.CsrfPreventionFilter\$LruCache(?:\$1)?|java\.util\.(?:Linked)?HashMap"/>
# </Context>
# EOF

    # 2. "webapps/manager/META-INF/context.xml" (enable tomcat manager)
    cat <<EOF > "${appDataDirsDefault[APP_DATA]}/manager/META-INF/context.xml"
<Context antiResourceLocking="false" privileged="true" >
  <Valve className="org.apache.catalina.valves.RemoteAddrValve" allow=".*" />
  <Manager sessionAttributeValueClassNameFilter="java\.lang\.(?:Boolean|Integer|Long|Number|String)|org\.apache\.catalina\.filters\.CsrfPreventionFilter\$LruCache(?:\$1)?|java\.util\.(?:Linked)?HashMap"/>
</Context>
EOF
  fi

  # 3. context.xml
  echo "---> configuring ${appDataDirsDefault[APP_CONF]}/context.xml"
  cat <<EOF > "${appDataDirsDefault[APP_CONF]}/context.xml"
<?xml version="1.0" encoding="UTF-8"?>
  <Context antiResourceLocking="false" privileged="true" >
    <WatchedResource>WEB-INF/web.xml</WatchedResource>
    <WatchedResource>WEB-INF/tomcat-web.xml</WatchedResource>
    <WatchedResource>\${catalina.base}/conf/web.xml</WatchedResource>
  </Context>
EOF

  # 4. server.xml (set resource limits)
  echo "---> configuring ${appDataDirsDefault[APP_CONF]}/server.xml"
  MATCH='<Connector port="8080" protocol="HTTP\/1.1"'
  sed "/$MATCH/a maxThreads=\"512\"" -i "${appDataDirsDefault[APP_CONF]}/server.xml"
  sed "/$MATCH/a maxConnections=\"512\"" -i "${appDataDirsDefault[APP_CONF]}/server.xml"

  local MATCH='<Connector port="8009" protocol="AJP\/1.3"'
  sed "/$MATCH/a maxThreads=\"512\"" -i "${appDataDirsDefault[APP_CONF]}/server.xml"
  sed "/$MATCH/a maxConnections=\"512\"" -i "${appDataDirsDefault[APP_CONF]}/server.xml"


  # 5. tomcat-users.xml create web admin user
  echo "---> configuring ${appDataDirsDefault[APP_CONF]}/tomcat-users.xml"
  echo "----> creating '$APP_ADMIN_USERNAME' user with a '${PASSWORD_TYPE}' password"
  cat <<EOF > "${appDataDirsDefault[APP_CONF]}/tomcat-users.xml"
<?xml version="1.0" encoding="UTF-8"?>
<tomcat-users xmlns="http://tomcat.apache.org/xml"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xsi:schemaLocation="http://tomcat.apache.org/xml tomcat-users.xsd"
              version="1.0">
  <role rolename="manager"/>
  <role rolename="manager-gui"/>
  <role rolename="manager-script"/>
  <role rolename="manager-jmx"/>
  <role rolename="admin"/>
  <role rolename="admin-gui"/>
  <role rolename="admin-script"/>
  <user username="$APP_ADMIN_USERNAME" password="$APP_ADMIN_PASSWORD" roles="manager,manager-gui,manager-script,manager-jmx,admin,admin-gui,admin-script"/>
</tomcat-users>
EOF

  ## other customizations
  # enhance security
  chmod o-rwx "${appDataDirsDefault[APP_CONF]}/tomcat-users.xml"

  ## remove unused files
  # avoid Failed to scan from classloader hierarchy errors for webservices-*.jar jars
  sed 's/tomcat.util.scan.StandardJarScanFilter.jarsToSkip=\\/tomcat.util.scan.StandardJarScanFilter.jarsToSkip=\\\nwebservices-*.jar,\\/' -i "${CATALINA_HOME}/conf/catalina.properties"

  # disable ssl engine by default
  #sed 's/SSLEngine="on"/SSLEngine="off"/g' -i "${CATALINA_HOME}/conf/server.xml"

  # disable java assistive_technologies to avoid errors like java.awt.AWTError: Assistive Technology not found: org.GNOME.Accessibility.AtkWrapper (not working since tomcat:8.5.42-jdk8-openjdk-slim)
  #sed -e '/^assistive_technologies=/s/^/#/' -i /etc/java-*-openjdk/accessibility.properties && \

  # test: fix infinite dns cache jvm
  #echo "networkaddress.cache.ttl=60" >> /usr/lib/jvm/default-jvm/jre/lib/security/java.security

  # TESTING custom context.xml for defining database
  # link ${appDataDirsDefault[APP_HOME]}/conf/[enginename]/[hostname]/context.xml to ${appDataDirsDefault[APP_SHARED]}/conf/context.xml if exist
#   if [ -e "${appDataDirsDefault[APP_SHARED]}/conf/context.xml" ]; then
#     echo "=> linking ${appDataDirsDefault[APP_SHARED]}/conf/context.xml to ${appDataDirsDefault[APP_HOME]}/conf/Catalina/localhost/context.xml"
#     ln -s "${appDataDirsDefault[APP_SHARED]}/conf/context.xml" "${appDataDirsDefault[APP_HOME]}/conf/Catalina/localhost/context.xml.default"
#   fi

  echo "=> All Done!"

  if [ "$PASSWORD_TYPE" = "random" ]; then
    echo
    echo "========================================================================"
    echo "You can now connect to this $APP_NAME deploy using:"
    echo "> username: ${APP_ADMIN_USERNAME}"
    echo "> password: ${APP_ADMIN_PASSWORD}"
    echo "========================================================================"
    echo
  fi

  # save the configuration status for later usage if using persistent data
  initizializeDir "${appDataDirsDefault[APP_CONF]}" "${appDataDirsCustom[APP_CONF]}" "$(printf '[%02d/%d]' $n $t)"
}



## misc functions
check_version() { printf "%03d%03d%03d%03d" $(echo "$1" | tr '.' ' '); }
print_path() { echo ${@%/*}; }
print_fullname() { echo ${@##*/}; }
print_name() { print_fullname $(echo ${@%.*}); }
print_ext() { echo ${@##*.}; }
dirEmpty() { [ -z "$(ls -A "$1/")" ]; } # return true if specified directory is empty, false if contains files

initizializeDir() {
  local dirDefault="$1"
  shift
  local dirCustom="$1"
  shift
  local prefixLog="$1"

  if [ -z "$prefixLog" ];then
    local prefix="--> "
    local prefixIndent="--> "
  else
    local prefix="--> $prefixLog "
    local prefixIndent="$(echo $prefixLog | sed 's/[][\/a-zA-Z0-9]/-/g')---> "
  fi

  # verify if $dirDefault and $dirCustom are not the same directory
  if [ ! -z "$dirCustom" ]; then
    # copy data files form default directory if destination is empty
    if [ -e "$dirDefault" ] && dirEmpty "$dirCustom"; then
      echo -e "${prefixIndent}INFO: [$dirDefault] empty dir detected copying files to '$dirCustom'..."
      cp -a -f "$dirDefault"/* "$dirCustom"/
      echo -e "${prefixIndent}INFO: [$dirDefault] setting owner with user '${APP_USR}' (UID:${APP_UID}) and group '${APP_GRP}' (GID:${APP_GID}) on '${dirCustom}'"
      chown -R ${APP_USR}:${APP_GRP} "$dirCustom"/
    # copy data files form default directory if destination is not initialized
    elif [ ! -f "${dirCustom}/.initialized" ]; then
      echo -e "${prefixIndent}INFO: [$dirDefault] not initialized persistent data storage detected in '${dirCustom}/.initialized'... coping default files from '${dirDefault}' to '${dirCustom}'"
      cp -a -f "$dirDefault"/* "$dirCustom"/
      echo -e "${prefixIndent}INFO: [$dirDefault] setting owner with user '${APP_USR}' (UID:${APP_UID}) and group '${APP_GRP}' (GID:${APP_GID}) on '${dirCustom}'"
      chown -R ${APP_USR}:${APP_GRP} "$dirCustom"/
      else
      echo -e "${prefixIndent}INFO: [$dirDefault] skipping data initialization... '$dirCustom' data dir is already initialized"
    fi
  fi

  # make the dirCustom initialized unsing ISO 8601:2004 extended time format: https://en.wikipedia.org/wiki/ISO_8601
  [[ -e "${dirCustom}" && ! -f "${dirCustom}/.initialized" ]] && echo "$(date +"%Y-%m-%dT%H:%M:%S%:z")" > "${dirCustom}/.initialized";
}

# if required move default confgurations to custom directory
symlinkDir() {
  #set -e

  local dirDefault="$1"
  shift
  local dirCustom="$1"
  shift
  local prefixLog="$1"

  if [ -z "$prefixLog" ];then
    local prefix="--> "
    local prefixIndent="--> "
  else
    local prefix="--> $prefixLog "
    local prefixIndent="$(echo $prefixLog | sed 's/[][\/a-zA-Z0-9]/-/g')---> "
  fi

  if [ ! -z "$dirCustom" ]; then
    echo -e "${prefix}INFO: [$dirDefault] detected directory data override path: '$dirCustom'"

    if [ ! -e "$dirCustom" ]; then
      # make destination dir if not exist
      echo -e "${prefixIndent}WARN: [$dirCustom] custom directory doesn't exist... creating empty directory"
      mkdir -p "$dirCustom"
    fi

    if [ ! -e "$dirDefault" ]; then
      # make default dir if not exist
      echo -e "${prefixIndent}WARN: [$dirDefault] default directory doesn't exist... creating empty directory"
      mkdir -p "$dirDefault"
    fi

    # rename default directory
    if [ -e "$dirDefault" ]; then
      echo -e "${prefixIndent}INFO: [$dirDefault] renaming to '${dirDefault}.dist'"
      mv "$dirDefault" "$dirDefault".dist
    fi

    # symlink default directory to custom directory
    echo -e "${prefixIndent}INFO: [$dirDefault] symlinking '$dirDefault' to '$dirCustom'"
    ln -s "$dirCustom" "$dirDefault"
   else
     echo "${prefix}WARN: [$dirDefault] no custom persistent storage path defined... all data placed into '$dirDefault' will be lost on container restart"
  fi
}

symlinkFile() {
  #set -e

  local fileDefault="$1"
  shift
  local fileCustom="$1"
  shift
  local prefixLog="$1"

  if [ -z "$prefixLog" ];then
    local prefix="--> "
    local prefixIndent="--> "
  else
    local prefix="--> $prefixLog "
    local prefixIndent="$(echo $prefixLog | sed 's/[][\/a-zA-Z0-9]/-/g')---> "
  fi

  echo -e "${prefix}INFO: [$fileDefault] file data override detected: default:[$fileDefault] custom:[$fileCustom]"

  if [ -e "$fileDefault" ]; then
      # copy data files form default directory if destination is empty
      if [ ! -e "$fileCustom" ]; then
        echo -e "${prefixIndent}INFO: [$fileDefault] detected not existing file '$fileCustom'. copying '$fileDefault' to '$fileCustom'..."
        cp -a -f "$fileDefault" "$fileCustom"
      fi
      echo -e "${prefixIndent}INFO: [$fileDefault] renaming to '${fileDefault}.dist'... "
      mv "$fileDefault" "$fileDefault".dist
    else
      echo -e "${prefixIndent}WARN: [$fileDefault] default file doesn't exist... creating symlink from a not existing source file"
      #touch "$fileDefault"
  fi

  echo -e "${prefixIndent}INFO: [$fileDefault] symlinking '$fileDefault' to '$fileCustom'"
  # create parent dir if not exist
  [ ! -e "$(dirname "$fileCustom")" ] && mkdir -p "$(dirname "$fileCustom")"
  # link custom file over orinal path
  ln -s "$fileCustom" "$fileDefault"
}

runHooks
