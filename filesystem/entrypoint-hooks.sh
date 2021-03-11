#!/bin/bash

: ${UMASK:=0002} # (**0002**) default umask when creating new files

# tomcat hooks
hooks_always() {
        echo "=> Hooks ALWAYS - ALL: Executing $APP_NAME configuration hooks..."
}

hooks_onetime_conf() {
echo "=> Hooks ONETIME - CONF: Executing $APP_NAME configuration hooks 'onetime'..."
PASSWORD_TYPE=$( [ ${APP_ADMIN_PASSWORD} ] && echo "preset" || echo "random" )

APP_ADMIN_USERNAME="${APP_ADMIN_USERNAME:-manager}"
APP_ADMIN_PASSWORD="${APP_ADMIN_PASSWORD:-$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ; echo '')}"

# use the env variables to make initial configuration changes before starting for the first time
APP_REMOTE_MANAGEMENT="${APP_REMOTE_MANAGEMENT:-0}"

echo "--> setting default system umask to $UMASK "
# set default umask
export UMASK
umask $UMASK
sed "s/^UMASK.*/UMASK $UMASK/" -i /etc/login.defs

if [ $APP_RECONFIG = 0 ]; then
  echo "==> not reconfiguring $APP_NAME because APP_RECONFIG=0"
else

# tomcat Catalina/localhost/manager.xml (allow remote management)
if [ $APP_REMOTE_MANAGEMENT = 1 ]; then
  echo "--> configuring ${APP_CONF_DEFAULT}/Catalina/localhost/manager.xml"
  mkdir -p "${APP_CONF_DEFAULT}/Catalina/localhost"
  echo '<Context privileged="true" antiResourceLocking="false" docBase="${catalina.home}/webapps/manager">
  <Valve className="org.apache.catalina.valves.RemoteAddrValve" allow="^.*$" />
  </Context>' > "${APP_CONF_DEFAULT}/Catalina/localhost/manager.xml"

  echo '<Context antiResourceLocking="false" privileged="true" />' > "${APP_DATA_DEFAULT}/manager/META-INF/context.xml"
fi

# tomcat context.xml
echo "--> configuring ${APP_CONF_DEFAULT}/context.xml"
echo '<?xml version="1.0" encoding="UTF-8"?>
<Context antiResourceLocking="false" privileged="true" >
  <WatchedResource>WEB-INF/web.xml</WatchedResource>
  <WatchedResource>${catalina.base}/conf/web.xml</WatchedResource>
</Context>' > "${APP_CONF_DEFAULT}/context.xml"

# tomcat server.xml (set resource limits)
echo "==> configuring ${APP_CONF_DEFAULT}/server.xml"
MATCH='<Connector port="8080" protocol="HTTP\/1.1"'
sed "/$MATCH/a maxThreads=\"512\"" -i "${APP_CONF_DEFAULT}/server.xml"
sed "/$MATCH/a maxConnections=\"512\"" -i "${APP_CONF_DEFAULT}/server.xml"

local MATCH='<Connector port="8009" protocol="AJP\/1.3"'
sed "/$MATCH/a maxThreads=\"512\"" -i "${APP_CONF_DEFAULT}/server.xml"
sed "/$MATCH/a maxConnections=\"512\"" -i "${APP_CONF_DEFAULT}/server.xml"
fi

# create web admin user
echo "==> creating $APP_ADMIN_USERNAME user with a ${PASSWORD_TYPE} password in ${APP}"
echo "==> configuring ${APP_CONF_DEFAULT}/tomcat-users.xml"

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
</tomcat-users>" > "${APP_CONF_DEFAULT}/tomcat-users.xml"

# link ${APP_HOME}/conf/[enginename]/[hostname]/context.xml to ${APP_SHARED_DEFAULT}/conf/context.xml if exist
if [ -e "${APP_SHARED_DEFAULT}/conf/context.xml" ]; then
 echo "=> linking ${APP_SHARED_DEFAULT}/conf/context.xml to ${APP_HOME}/conf/Catalina/localhost/context.xml"
 ln -s "${APP_SHARED_DEFAULT}/conf/context.xml" "${APP_HOME}/conf/Catalina/localhost/context.xml.default"
fi

echo "=> Done!"

if [ "$PASSWORD_TYPE" = "random" ]; then
echo "========================================================================"
echo "You can now connect to this $APP_NAME using:"
echo "  username: ${APP_ADMIN_USERNAME}"
echo "  password: ${APP_ADMIN_PASSWORD}"
echo "========================================================================"
fi

# save the configuration status for later usage with persistent volumes
touch "${APP_CONF_DEFAULT}/.configured"
}

hooks_onetime_data() {
echo "=> Hooks ONETIME - DATA: Executing $APP_NAME data hooks 'onetime'..."
cp -a "${APP_DATA_DEFAULT}".dist/* "${APP_DATA_DEFAULT}"/
[ $? = 0 ] && touch "${APP_DATA_DEFAULT}/.initialized"

# tomcat bad configuration workaround:
[ -e "${APP_DATA_DEFAULT}/webapps" ] && rmdir "${APP_DATA_DEFAULT}/webapps"
}

# always execute these hooks
hooks_always

# copy default data files if the directory is not initialized
if [ ! -f "${APP_DATA_DEFAULT}/.initialized" ]; then
    hooks_onetime_data
  else
    echo "=> Skipping Hooks ONETIME - DATA: Detected $APP_NAME data files already initialized into '${APP_DATA_DEFAULT}'"
fi

if [ ! -f "${APP_CONF_DEFAULT}/.configured" ]; then
    hooks_onetime_conf
  else
    echo "=> Skipping Hooks ONETIME - CONF: Detected $APP_NAME configurations already initialized into '${APP_CONF_DEFAULT}'"
fi
