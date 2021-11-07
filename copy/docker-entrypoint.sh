#!/bin/sh
# Same settings as in Dockerfile:
REPOSITORY_ROOT='/repos'
REPOSITORY_DUMMY="$REPOSITORY_ROOT/If_you_see_this_then_the_host_volume_was_not_mounted"


# Abort if the host's volume was not mounted read-only.
if [ ! -d "$REPOSITORY_DUMMY" ]; then
	#RO=$(findmnt -no 'OPTIONS' "$REPOSITORY_ROOT" 2>&1 | tr , "\n" | grep -F ro);	# part of util-linux package
	RO=$(sed -En 's|^\S+\s+'"$REPOSITORY_ROOT"'\s+\S+\s+(\S+).*|\1|p' < /proc/mounts | tr , "\n" | grep -F ro)
	if [ -z "$RO" ]; then
		echo "$0: Aborted to protect you from your own bad habits because you didn't mount the volume $REPOSITORY_ROOT read-only using the :ro attribute" >&2
		exit 1
	fi
fi


# Default entrypoint (as defined by Dockerfile CMD):
if [ "$(echo $1 | cut -c1-7)" = 'gitlist' ] || [ "$1" = 'shell' ]; then
	GITLIST_ROOT='/var/www/gitlist'
	GITLIST_CACHE_DIR="$GITLIST_ROOT/cache"
	GITLIST_CONFIG_FILE="$GITLIST_ROOT/config.ini"
	PHP_FPM_GID_FILE='/etc/php82/php-fpm.d/zz_gid.conf'
	PHP_FPM_UID_FILE='/etc/php82/php-fpm.d/zz_uid.conf'

	# Set gid of php-fpm so that it can read the host's volume
	if [ ! -d "$REPOSITORY_DUMMY" ]; then
		if [ -z "$GITLIST_GID" ]; then
			# GITLIST_GID not given and volume was mounted, so read gid from mounted volume.
			GITLIST_GID=$(stat -c%g "$REPOSITORY_ROOT")
			echo "$0: Host's volume has gid $GITLIST_GID" >&2
		elif ! echo "$GITLIST_GID" | grep -qE '^[0-9]{1,9}$'; then
			echo "$0: Bad gid syntax in GITLIST_GID environment variable ($GITLIST_GID)" >&2
			exit 1
		fi
		CURRENT_GROUP=
		CURRENT_GID=
		if [ -f "$PHP_FPM_GID_FILE" ]; then
			CURRENT_GROUP=$(sed -En 's/^group\s*=\s*(\S+)\s*$/\1/p' < "$PHP_FPM_GID_FILE")
			if [ -n "$CURRENT_GROUP" ]; then
				CURRENT_GID=$(getent group "$CURRENT_GROUP" | cut -d: -f3)
			fi
		fi
		if [ "$GITLIST_GID" = "$CURRENT_GID" ]; then
			echo "$0: php-fpm is already configured to use the gid $GITLIST_GID($CURRENT_GROUP)"
		else
			GROUP=$(getent group "$GITLIST_GID" | cut -d: -f1)
			if [ -z "$GROUP" ]; then	# no existing group has the requested gid; so create the gitlist group for this
				if [ "$(id -u)" = '0' ]; then
					GROUP=gitlist
					addgroup -g "$GITLIST_GID" "$GROUP"
				else
					echo "$0: You need to run this script as root in order to add a new group" >&2
					exit 1
				fi
			else
				:	# the requested gid belongs to an existing group name, so just use that
			fi
			printf "\n[www]\ngroup=%s\n" "$GROUP" > "$PHP_FPM_GID_FILE"
			chgrp -R "$GROUP" "$GITLIST_CACHE_DIR"
			echo "$0: php-fpm gid set to $GITLIST_GID ($GROUP)"
		fi
		if [ -n "$GITLIST_UID" ]; then
			printf "\n[www]\nuser=%s\n" "$GITLIST_UID" > "$PHP_FPM_UID_FILE"
			chown -R "$GITLIST_UID" "$GITLIST_CACHE_DIR"
			echo "$0: php-fpm uid set to $GITLIST_UID"
		fi
	fi

	# Set SSH host
	if [ -n "$SSH_HOST" ]; then
		sed -i 's/^\(show_ssh_remote =\).*$/\1 true/g' "$GITLIST_CONFIG_FILE"
		sed -i "s/^\(ssh_host =\).*$/\1 '${SSH_HOST}'/g" "$GITLIST_CONFIG_FILE"
	else
		sed -i 's/^\(show_ssh_remote =\).*$/\1 false/g' "$GITLIST_CONFIG_FILE"
	fi

	# Set SSH host
	if [ -n "$TITLE" ]; then
		sed -i "s/^\(title =\).*$/\1 '${TITLE}'/g" "$GITLIST_CONFIG_FILE"
	fi

	if [ "$1" = 'shell' ]; then
		# Enter the shell
		echo 'Start supervisord with: /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf'
		exec /bin/sh
	else
		# Start nginx and php-fpm
		exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
	fi
else
	# All other entry points. Typically /bin/sh
	exec "$@"
fi
