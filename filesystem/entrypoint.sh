#!/bin/bash
# initzero docker entrypoint init script
# written by Ugo Viti <ugo.viti@initzero.it>
# 20200315

#set -x

appHooks() {
  : ${APP_RUNAS:="false"}
  : ${ENTRYPOINT_TINI:="false"}
  : ${MULTISERVICE:="false"}
  : ${APP_NAME:=CHANGEME}
  : ${APP_DESCRIPTION:=CHANGEME}
  : ${APP_VER:="latest"}
  : ${APP_VER_BUILD:="unknown"}
  : ${APP_BUILD_COMMIT:="unknown"}
  : ${APP_BUILD_DATE:="unknown"}

  [ "${APP_BUILD_DATE}" != "unknown" ] && APP_BUILD_DATE=$(date -d @${APP_BUILD_DATE} +"%Y-%m-%d")
  
  echo "=> Starting container $APP_DESCRIPTION -> $APP_NAME:$APP_VER (build:${APP_VER_BUILD} commit:${APP_BUILD_COMMIT} date:${APP_BUILD_DATE})"
  echo "==============================================================================="

  # verify if exist custom directory overrides
  if [ $APP_RELINK = 1 ]; then
  [ ! -z "${APP_CONF}" ] && relink_dir "${APP_CONF_DEFAULT}" "${APP_CONF}"
  [ ! -z "${APP_DATA}" ] && relink_dir "${APP_DATA_DEFAULT}" "${APP_DATA}"
  [ ! -z "${APP_LOGS}" ] && relink_dir "${APP_LOGS_DEFAULT}" "${APP_LOGS}"
  [ ! -z "${APP_TEMP}" ] && relink_dir "${APP_TEMP_DEFAULT}" "${APP_TEMP}"
  [ ! -z "${APP_WORK}" ] && relink_dir "${APP_WORK_DEFAULT}" "${APP_WORK}"
  [ ! -z "${APP_SHARED}" ] && relink_dir "${APP_SHARED_DEFAULT}" "${APP_SHARED}"
  else
    echo "=> Skipping APP directories relinking"
  fi
  
  echo "=> Executing $APP_NAME hooks:"
  . /entrypoint-hooks.sh
  echo "-------------------------------------------------------------------------------"
}

# if required move configurations and webapps dirs to custom directory
relink_dir() {
	local dir_default="$1"
	local dir_custom="$2"

	# make destination dir if not exist
	[ ! -e "$dir_default" ] && mkdir -p "$dir_default"
	[ ! -e "$(dirname "$dir_custom")" ] && mkdir -p "$(dirname "$dir_custom")"

	echo "$APP_DESCRIPTION directory container override detected! default: $dir_default custom: $dir_custom"
	if [ ! -e "$dir_custom" ]; then
		echo -e -n "=> moving the $dir_default directory to $dir_custom ..."
		mv "$dir_default" "$dir_custom"
	else
		echo -e -n "=> directory $dir_custom already exist... "
		mv "$dir_default" "$dir_default".dist
	fi
	echo "linking $dir_custom into $dir_default"
	ln -s "$dir_custom" "$dir_default"
}

# exec app hooks
appHooks

# set default system umask before starting the container
[ ! -z "$UMASK" ] && umask $UMASK

# use tini init manager if defined in Dockerfile
[ "$ENTRYPOINT_TINI" = "true" ] && ENTRYPOINT="tini -g --" || ENTRYPOINT=""

# if this container will run multiple commands, override the entry point cmd
echo "=> Executing $APP_NAME entrypoint command: $@"
echo "==============================================================================="
if [ "$MULTISERVICE" = "true" ]; then
  set -x
  exec $ENTRYPOINT runsvdir -P /etc/service
 else
  # run the process as user if specified
  if [ "$APP_RUNAS" = "true" ]; then
      set -x
      exec $ENTRYPOINT runuser -p -u $APP_USR -- $@
    else
      set -x
      exec $ENTRYPOINT $@
  fi
fi
exit $?
