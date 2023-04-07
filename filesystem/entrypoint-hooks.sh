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

# override default data directory used by container apps (used by stateful apps)
: ${APP_DATA:=""}
: ${APP_SHARED:=""}

# default original directory and config files paths array used by container app
declare -A appDataDirs=(
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
# arg1: <VARIABLE_NAME> define the variable name containing base path for persistent storage
# arg2: <VARIABLE_NAME> define the array name containing all app directory paths
# arg3: <yes/no> yes = create the Parents full path of default path using the persistent data path as basedir. no or no value = use the persistent data path directly as final data destination
manageDataDir() {
  # import custom dir variable name
  eval dirCustom="\$$1"
  shift

  # import original dir array name (dirsOriginal is an Associative Array)
  # clone the source array into a new temporary array
  eval dirsOriginalIndexs=\${!$1[*]}
  declare -A dirsOriginal
  for i in $dirsOriginalIndexs; do
    eval dirsOriginal[$i]=\${$1 [$i]}
  done
  unset dirsOriginalIndexs
  shift

  # define if the custom dir must contain parents full path of original dir
  eval makeParents="\$$1"
  shift

  if [ ! -f "${dirCustom}/.initialized" ]; then
    echo "==> Persistent storage path detected... relocating and reconfiguring system data and configuration files using basedir: '${appDataDirCustom}'"

    # link to custom data directory if required
    local n=1 ; local t=$(echo ${#dirsOriginal[@]})
    for dirOriginalStep in ${dirsOriginal[@]}; do
      [[ ! -z "${makeParents}" && "${makeParents}" = "yes" ]] && dirCustomStep="${dirCustom}${dirOriginalStep}" || dirCustomStep="${dirCustom}"
      symlinkDir "${dirOriginalStep}" "${dirCustomStep}" "$(printf '[%02d/%d]' $n $t)"
      [[ ! -z "$RETVAL" && $RETVAL != 1 ]] && RETVAL=$?
      let n+=1
    done

    # make initialized only on sucessfull directory symlinking
    [ $RETVAL = 0 ] && makeInitialized "${appDataDirs[APP_DATA]}"
  else
      echo "==> Skipping Initialization Hooks: Detected $APP_NAME data files already initialized into '${appDataDirs[APP_DATA]}'"
  fi
}


## entrypoint functions
runHooks() {
  [ ! -z "${APP_DATA}" ]   && manageDataDir APP_DATA   appDataDirs no || echo "==> WARNING: No Persistent storage path detected for APP_DATA... all data will be lost on container restart"
  [ ! -z "${APP_SHARED}" ] && manageDataDir APP_SHARED appDataDirs no || echo "==> WARNING: No Persistent storage path detected for APP_SHARED... all data will be lost on container restart"

  # stop debugging
  #exit

  # copy default data files if the directory is not initialized
  if [ ! -f "${appDataDirs[APP_CONF]}/.initialized" ]; then
      tomcatConf
    else
      echo "==> Skipping Configuration Hooks: Detected $APP_NAME configurations already initialized into '${appDataDirs[APP_CONF]}'"
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

  # 1. Catalina/localhost/manager.xml (allow remote management)
  if [ $APP_REMOTE_MANAGEMENT = 1 ]; then
    echo "---> configuring ${appDataDirs[APP_CONF]}/Catalina/localhost/manager.xml"
    mkdir -p "${appDataDirs[APP_CONF]}/Catalina/localhost"
    echo '<Context privileged="true" antiResourceLocking="false" docBase="${catalina.home}/webapps/manager">
    <Valve className="org.apache.catalina.valves.RemoteAddrValve" allow="^.*$" />
    </Context>' > "${appDataDirs[APP_CONF]}/Catalina/localhost/manager.xml"

    echo '<Context antiResourceLocking="false" privileged="true" />' > "${appDataDirs[APP_DATA]}/manager/META-INF/context.xml"
  fi

  # 2. context.xml
  echo "---> configuring ${appDataDirs[APP_CONF]}/context.xml"
  echo '<?xml version="1.0" encoding="UTF-8"?>
  <Context antiResourceLocking="false" privileged="true" >
    <WatchedResource>WEB-INF/web.xml</WatchedResource>
    <WatchedResource>${catalina.base}/conf/web.xml</WatchedResource>
  </Context>' > "${appDataDirs[APP_CONF]}/context.xml"

  # 3. server.xml (set resource limits)
  echo "---> configuring ${appDataDirs[APP_CONF]}/server.xml"
  MATCH='<Connector port="8080" protocol="HTTP\/1.1"'
  sed "/$MATCH/a maxThreads=\"512\"" -i "${appDataDirs[APP_CONF]}/server.xml"
  sed "/$MATCH/a maxConnections=\"512\"" -i "${appDataDirs[APP_CONF]}/server.xml"

  local MATCH='<Connector port="8009" protocol="AJP\/1.3"'
  sed "/$MATCH/a maxThreads=\"512\"" -i "${appDataDirs[APP_CONF]}/server.xml"
  sed "/$MATCH/a maxConnections=\"512\"" -i "${appDataDirs[APP_CONF]}/server.xml"


  # 4. tomcat-users.xml create web admin user
  echo "---> configuring ${appDataDirs[APP_CONF]}/tomcat-users.xml"
  echo "----> creating '$APP_ADMIN_USERNAME' user with a '${PASSWORD_TYPE}' password"
  echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
  <tomcat-users>
    <role rolename=\"manager\"/>
    <role rolename=\"manager-gui\"/>
    <role rolename=\"manager-script\"/>
    <role rolename=\"manager-jmx\"/>
    <role rolename=\"admin\"/>
    <role rolename=\"admin-gui\"/>
    <role rolename=\"admin-script\"/>
    <user username=\"$APP_ADMIN_USERNAME\" password=\"$APP_ADMIN_PASSWORD\" roles=\"manager,manager-gui,manager-script,manager-jmx,admin,admin-gui,admin-script\"/>
  </tomcat-users>" > "${appDataDirs[APP_CONF]}/tomcat-users.xml"

  # link ${appDataDirs[APP_HOME]}/conf/[enginename]/[hostname]/context.xml to ${appDataDirs[APP_SHARED]}/conf/context.xml if exist
  if [ -e "${appDataDirs[APP_SHARED]}/conf/context.xml" ]; then
    echo "=> linking ${appDataDirs[APP_SHARED]}/conf/context.xml to ${appDataDirs[APP_HOME]}/conf/Catalina/localhost/context.xml"
    ln -s "${appDataDirs[APP_SHARED]}/conf/context.xml" "${appDataDirs[APP_HOME]}/conf/Catalina/localhost/context.xml.default"
  fi

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

  # save the configuration status for later usage with persistent volumes
  makeInitialized "${appDataDirs[APP_CONF]}"
}



## misc functions
check_version() { printf "%03d%03d%03d%03d" $(echo "$1" | tr '.' ' '); }
print_path() { echo ${@%/*}; }
print_fullname() { echo ${@##*/}; }
print_name() { print_fullname $(echo ${@%.*}); }
print_ext() { echo ${@##*.}; }
dirEmpty() { [ -z "$(ls -A "$1/")" ]; } # return true if specified directory is empty, false if contains files

makeInitialized() {
  # ISO 8601:2004 time format
  # https://en.wikipedia.org/wiki/ISO_8601
  echo "$(date +"%Y-%m-%dT%H:%M:%S%z")" > "$1/.initialized"
}

# if required move default confgurations to custom directory
symlinkDir() {
  set -e

  local dirOriginal="$1"
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

  echo -e "${prefix}INFO: [$dirOriginal] detected directory data override path: '$dirCustom'"

  if [ ! -e "$dirCustom" ]; then
    # make destination dir if not exist
    echo -e "${prefixIndent}WARN: [$dirCustom] custom directory doesn't exist... creating empty directory"
    mkdir -p "$dirCustom"
  fi

  # copy data files form original directory if destination is empty
  if [ -e "$dirOriginal" ] && dirEmpty "$dirCustom"; then
    echo -e "${prefixIndent}INFO: [$dirOriginal] empty dir detected copying files to '$dirCustom'..."
    cp -a -f "$dirOriginal/*" "$dirCustom/"
  elif [ ! -e "$dirOriginal" ]; then
    # make original dir if not exist
    echo -e "${prefixIndent}WARN: [$dirOriginal] original directory doesn't exist... creating empty directory"
    mkdir -p "$dirOriginal"
  fi

  # rename original directory
  if [ -e "$dirOriginal" ]; then
    echo -e "${prefixIndent}INFO: [$dirOriginal] renaming to '${dirOriginal}.dist'"
    mv "$dirOriginal" "$dirOriginal".dist
  fi

  # symlink original directory to custom directory
  echo -e "${prefixIndent}INFO: [$dirOriginal] symlinking '$dirCustom' to '$dirOriginal'"
  ln -s "$dirCustom" "$dirOriginal"
}

symlinkFile() {
  set -e

  local fileOriginal="$1"
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

  echo -e "${prefix}INFO: [$fileOriginal] file data override detected: original:[$fileOriginal] custom:[$fileCustom]"

  if [ -e "$fileOriginal" ]; then
      # copy data files form original directory if destination is empty
      if [ ! -e "$fileCustom" ]; then
        echo -e "${prefixIndent}INFO: [$fileOriginal] detected not existing file '$fileCustom'. copying '$fileOriginal' to '$fileCustom'..."
        cp -a -f "$fileOriginal" "$fileCustom"
      fi
      echo -e "${prefixIndent}INFO: [$fileOriginal] renaming to '${fileOriginal}.dist'... "
      mv "$fileOriginal" "$fileOriginal".dist
    else
      echo -e "${prefixIndent}WARN: [$fileOriginal] original file doesn't exist... creating symlink from a not existing source file"
      #touch "$fileOriginal"
  fi

  echo -e "${prefixIndent}INFO: [$fileOriginal] symlinking '$fileCustom' to '$fileOriginal'"
  # create parent dir if not exist
  [ ! -e "$(dirname "$fileCustom")" ] && mkdir -p "$(dirname "$fileCustom")"
  # link custom file over orinal path
  ln -s "$fileCustom" "$fileOriginal"
}

runHooks
