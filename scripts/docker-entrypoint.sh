#!/bin/sh -eu

###
### Variables
###
DEBUG_COMMANDS=0

# Default Xdebug remote port
PHP_XDEBUG_DEFAULT_PORT="9000"



###
### Functions
###
run() {
	_cmd="${1}"
	_debug="0"

	_red="\033[0;31m"
	_green="\033[0;32m"
	_reset="\033[0m"
	_user="$(whoami)"


	# If 2nd argument is set and enabled, allow debug command
	if [ "${#}" = "2" ]; then
		if [ "${2}" = "1" ]; then
			_debug="1"
		fi
	fi


	if [ "${DEBUG_COMMANDS}" = "1" ] || [ "${_debug}" = "1" ]; then
		printf "${_red}%s \$ ${_green}${_cmd}${_reset}\n" "${_user}"
	fi
	sh -c "LANG=C LC_ALL=C ${_cmd}"
}

log() {
	_lvl="${1}"
	_msg="${2}"

	_clr_ok="\033[0;32m"
	_clr_info="\033[0;34m"
	_clr_warn="\033[0;33m"
	_clr_err="\033[0;31m"
	_clr_rst="\033[0m"

	if [ "${_lvl}" = "ok" ]; then
		printf "${_clr_ok}[OK]   %s${_clr_rst}\n" "${_msg}"
	elif [ "${_lvl}" = "info" ]; then
		printf "${_clr_info}[INFO] %s${_clr_rst}\n" "${_msg}"
	elif [ "${_lvl}" = "warn" ]; then
		printf "${_clr_warn}[WARN] %s${_clr_rst}\n" "${_msg}" 1>&2	# stdout -> stderr
	elif [ "${_lvl}" = "err" ]; then
		printf "${_clr_err}[ERR]  %s${_clr_rst}\n" "${_msg}" 1>&2	# stdout -> stderr
	else
		printf "${_clr_err}[???]  %s${_clr_rst}\n" "${_msg}" 1>&2	# stdout -> stderr
	fi
}

# Test if argument is an integer.
#
# @param  mixed
# @return integer	0: is int | 1: not an int
isint() {
	echo "${1}" | grep -Eq '^([0-9]|[1-9][0-9]*)$'
}

isip() {
	# IP is not in correct format
	if ! echo "${1}" | grep -Eq '^([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})$'; then
		return 1
	fi

	# Get each octet
	o1="$( echo "${1}" | awk -F'.' '{print $1}' )"
	o2="$( echo "${1}" | awk -F'.' '{print $2}' )"
	o3="$( echo "${1}" | awk -F'.' '{print $3}' )"
	o4="$( echo "${1}" | awk -F'.' '{print $4}' )"

	# Cannot start with 0 and all must be below 256
	if [ "${o1}" -lt "1" ] || \
		[ "${o1}" -gt "255" ] || \
		[ "${o2}" -gt "255" ] || \
		[ "${o3}" -gt "255" ] || \
		[ "${o4}" -gt "255" ]; then
		return 1
	fi

	# All tests passed
	return 0
}
ishostname() {
	# Does not have correct character class
	if ! echo "${1}" | grep -Eq '^[-.0-9a-zA-Z]+$'; then
		return 1
	fi

	# first and last character
	f_char="$( echo "${1}" | cut -c1-1 )"
	l_char="$( echo "${1}" | sed -e 's/.*\(.\)$/\1/' )"

	# Dot at beginning or end
	if [ "${f_char}" = "." ] || [ "${l_char}" = "." ]; then
		return 1
	fi
	# Dash at beginning or end
	if [ "${f_char}" = "-" ] || [ "${l_char}" = "-" ]; then
		return 1
	fi
	# Multiple dots next to each other
	if echo "${1}" | grep -Eq '[.]{2,}'; then
		return 1
	fi
	# Dash next to dot
	if echo "${1}" | grep -Eq '(\.-)|(-\.)'; then
		return 1
	fi

	# All tests passed
	return 0
}


################################################################################
# BOOTSTRAP
################################################################################

if set | grep '^DEBUG_COMPOSE_ENTRYPOINT='  >/dev/null 2>&1; then
	if [ "${DEBUG_COMPOSE_ENTRYPOINT}" = "1" ]; then
		DEBUG_COMMANDS=1
	fi
fi



################################################################################
# MAIN ENTRY POINT
################################################################################

###
### Change UID
###
if ! set | grep '^NEW_UID=' >/dev/null 2>&1; then
	log "warn" "\$NEW_UID not set"
	log "warn" "Keeping user '${MY_USER}' with default uid: ${MY_UID}"
else
	if ! isint "${NEW_UID}"; then
		log "err" "\$NEW_UID is not an integer: '${NEW_UID}'"
		exit 1
	else
		log "info" "Changing user '${MY_USER}' uid to: ${NEW_UID}"
		run "usermod -u ${NEW_UID} ${MY_USER}"
	fi
fi



###
### Change GID
###
if ! set | grep '^NEW_GID=' >/dev/null 2>&1; then
	log "warn" "\$NEW_GID not set"
	log "warn" "Keeping group '${MY_GROUP}' with default gid: ${MY_GID}"
else
	if ! isint "${NEW_GID}"; then
		log "err" "\$NEW_GID is not an integer: '${NEW_GID}'"
		exit 1
	else
		log "info" "Changing group '${MY_GROUP}' gid to: ${NEW_GID}"
		run "groupmod -g ${NEW_GID} ${MY_GROUP}"
	fi
fi



###
### Use docker logs [error]?
###
if ! set | grep '^DOCKER_LOGS_ERROR=' >/dev/null 2>&1 || [ "${DOCKER_LOGS_ERROR}" != "1" ]; then

	# Why was it not enabled?
	if ! set | grep '^DOCKER_LOGS_ERROR=' >/dev/null 2>&1; then
		log "warn" "\$DOCKER_LOGS_ERROR not set."
		log "warn" "Not logging errors to docker logs, using file inside container"
	elif [ "${DOCKER_LOGS_ERROR}" = "0" ]; then
		log "info" "Not logging errors to docker logs, using file inside container"
	else
		log "err" "Invalid value for \$DOCKER_LOGS_ERROR: ${DOCKER_LOGS_ERROR}"
		log "err" "Must be '1' (for On) or '0' (for Off)"
		exit 1
	fi

	# Delete left-over symlinks from previous run (if docker-logs was enabled)
	if [ -L "${MY_LOG_FILE_ERR}" ]; then
		run "rm -f ${MY_LOG_FILE_ERR}"
	fi

	# Create files if not exists
	if [ ! -f "${MY_LOG_FILE_ERR}" ]; then
		run "touch ${MY_LOG_FILE_ERR}"
	fi

	# Fix permissions
	run "chmod 0664 ${MY_LOG_FILE_ERR}"
	run "chown ${MY_USER}:${MY_GROUP} ${MY_LOG_FILE_ERR}"

elif [ "${DOCKER_LOGS_ERROR}" = "1" ]; then
	log "info" "Logging errors to docker logs"
	run "ln -sf /proc/self/fd/2 ${MY_LOG_FILE_ERR}"
else
	log "err" "Invalid choice for \$DOCKER_LOGS_ERROR"
	exit 1
fi



###
### Use docker logs [access]?
###
#if ! set | grep '^DOCKER_LOGS_ACCESS=' >/dev/null 2>&1 || [ "${DOCKER_LOGS_ACCESS}" != "1" ]; then
#
#	# Why was it not enabled?
#	if ! set | grep '^DOCKER_LOGS_ACCESS=' >/dev/null 2>&1; then
#		log "warn" "\$DOCKER_LOGS_ACCESS not set."
#		log "warn" "Not logging access to docker logs, using file inside container"
#	elif [ "${DOCKER_LOGS_ACCESS}" = "0" ]; then
#		log "info" "Not logging access to docker logs, using file inside container"
#	else
#		log "err" "Invalid value for \$DOCKER_LOGS_ACCESS: ${DOCKER_LOGS_ACCESS}"
#		log "err" "Must be '1' (for On) or '0' (for Off)"
#		exit 1
#	fi
#
#	# Delete left-over symlinks from previous run (if docker-logs was enabled)
#	if [ -L "${MY_LOG_FILE_ACC}" ]; then
#		run "rm -f ${MY_LOG_FILE_ACC}"
#	fi
#
#	# Create files if not exists
#	if [ ! -f "${MY_LOG_FILE_ACC}" ]; then
#		run "touch ${MY_LOG_FILE_ACC}"
#	fi
#
#	# Fix permissions
#	run "chmod 0664 ${MY_LOG_FILE_ACC}"
#	run "chown ${MY_USER}:${MY_GROUP} ${MY_LOG_FILE_ACC}"
#
#elif [ "${DOCKER_LOGS_ACCESS}" = "1" ]; then
#	log "info" "Logging access to docker logs"
#	run "ln -sf /proc/self/fd/2 ${MY_LOG_FILE_ACC}"
#else
#	log "err" "Invalid choice for \$DOCKER_LOGS_ACCESS"
#	exit 1
#fi



###
### Use docker logs [xdebug]?
###
if ! set | grep '^DOCKER_LOGS_XDEBUG=' >/dev/null 2>&1 || [ "${DOCKER_LOGS_XDEBUG}" != "1" ]; then

	# Why was it not enabled?
	if ! set | grep '^DOCKER_LOGS_XDEBUG=' >/dev/null 2>&1; then
		log "warn" "\$DOCKER_LOGS_XDEBUG not set."
		log "warn" "Not logging xdebug to docker logs, using file inside container"
	elif [ "${DOCKER_LOGS_XDEBUG}" = "0" ]; then
		log "info" "Not logging xdebug to docker logs, using file inside container"
	else
		log "err" "Invalid value for \$DOCKER_LOGS_XDEBUG: ${DOCKER_LOGS_XDEBUG}"
		log "err" "Must be '1' (for On) or '0' (for Off)"
		exit 1
	fi

	# Delete left-over symlinks from previous run (if docker-logs was enabled)
	if [ -L "${MY_LOG_FILE_XDEBUG}" ]; then
		run "rm -f ${MY_LOG_FILE_XDEBUG}"
	fi

	# Create files if not exists
	if [ ! -f "${MY_LOG_FILE_XDEBUG}" ]; then
		run "touch ${MY_LOG_FILE_XDEBUG}"
	fi

	# Fix permissions
	run "chmod 0664 ${MY_LOG_FILE_XDEBUG}"
	run "chown ${MY_USER}:${MY_GROUP} ${MY_LOG_FILE_XDEBUG}"

elif [ "${DOCKER_LOGS_XDEBUG}" = "1" ]; then
	log "info" "Logging xdebug to docker logs"
	run "ln -sf /proc/self/fd/2 ${MY_LOG_FILE_XDEBUG}"
else
	log "err" "Invalid choice for \$DOCKER_LOGS_XDEBUG"
	exit 1
fi



###
### Adjust timezone
###
if ! set | grep '^TIMEZONE='  >/dev/null 2>&1; then
	log "warn" "\$TIMEZONE not set."
	log "warn" "Setting PHP: timezone=UTC"
	run "sed -i'' 's|;*date.timezone[[:space:]]*=.*$|date.timezone = UTC|g' /etc/hhvm/php.ini"
else
	if [ -f "/usr/share/zoneinfo/${TIMEZONE}" ]; then
		# Unix Time
		log "info" "Setting docker timezone to: ${TIMEZONE}"
		run "rm /etc/localtime"
		run "ln -s /usr/share/zoneinfo/${TIMEZONE} /etc/localtime"

		# PHP Time
		log "info" "Setting PHP: timezone=${TIMEZONE}"
		run "sed -i'' 's|;*date.timezone[[:space:]]*=.*$|date.timezone = ${TIMEZONE}|g' /etc/hhvm/php.ini"
	else
		log "err" "Invalid timezone for \$TIMEZONE."
		log "err" "\$TIMEZONE: '${TIMEZONE}' does not exist."
		exit 1
	fi
fi
log "info" "Docker date set to: $(date)"



###
### PHP Xdebug
###

if ! set | grep '^PHP_XDEBUG_ENABLE=' >/dev/null 2>&1; then
	log "warn" "\$PHP_XDEBUG_ENABLE not set. Not enabling Xdebug"

else
	# ---- 1/3 Enabled ----
	if [ "${PHP_XDEBUG_ENABLE}" = "1" ]; then

		# 1.1 Check Xdebug Port
		if ! set | grep '^PHP_XDEBUG_REMOTE_PORT=' >/dev/null 2>&1; then
			log "warn" "\$PHP_XDEBUG_REMOTE_PORT not set, defaulting to ${PHP_XDEBUG_DEFAULT_PORT}"
			PHP_XDEBUG_REMOTE_PORT="${PHP_XDEBUG_DEFAULT_PORT}"

		elif ! isint "${PHP_XDEBUG_REMOTE_PORT}"; then
			log "warn" "\$PHP_XDEBUG_REMOTE_PORT is not a valid integer: ${PHP_XDEBUG_REMOTE_PORT}"
			log "warn" "\Defaulting to ${PHP_XDEBUG_DEFAULT_PORT}"
			PHP_XDEBUG_REMOTE_PORT="${PHP_XDEBUG_DEFAULT_PORT}"

		elif [ "${PHP_XDEBUG_REMOTE_PORT}" -lt "1" ] || [ "${PHP_XDEBUG_REMOTE_PORT}" -gt "65535" ]; then
			log "warn" "\$PHP_XDEBUG_REMOTE_PORT is out of range: ${PHP_XDEBUG_REMOTE_PORT}"
			log "warn" "\Defaulting to ${PHP_XDEBUG_DEFAULT_PORT}"
			PHP_XDEBUG_REMOTE_PORT="${PHP_XDEBUG_DEFAULT_PORT}"
		fi

		# 1.2 Check Xdebug remote Host (IP address of Docker Host [your computer])
		if ! set | grep '^PHP_XDEBUG_REMOTE_HOST=' >/dev/null 2>&1; then
			log "err" "\$PHP_XDEBUG_REMOTE_HOST not set, but required."
			log "err" "\$PHP_XDEBUG_REMOTE_HOST should be the IP of your Host with the IDE to which xdebug can connect."
			exit 1
		fi

		# 1.4 Enable Xdebug
		log "info" "Setting PHP: xdebug.enable=1"
		run "echo 'xdebug.enable=1' >> /etc/hhvm/php.ini"

		log "info" "Setting PHP: xdebug.remote_enable=1"
		run "echo 'xdebug.remote_enable=1' >> /etc/hhvm/php.ini"

		log "info" "Setting PHP: xdebug.remote_connect_back=0"
		run "echo 'xdebug.remote_connect_back=0' >> /etc/hhvm/php.ini"

		log "info" "Setting PHP: xdebug.remote_port=${PHP_XDEBUG_REMOTE_PORT}"
		run "echo 'xdebug.remote_port=${PHP_XDEBUG_REMOTE_PORT}' >> /etc/hhvm/php.ini"

		# shellcheck disable=SC2153
		log "info" "Setting PHP: xdebug.remote_host=${PHP_XDEBUG_REMOTE_HOST}"
		run "echo 'xdebug.remote_host=${PHP_XDEBUG_REMOTE_HOST}' >> /etc/hhvm/php.ini"

		log "info" "Setting PHP: xdebug.remote_log=\"${MY_LOG_FILE_XDEBUG}\""
		run "echo 'xdebug.remote_log=\"${MY_LOG_FILE_XDEBUG}\"' >> /etc/hhvm/php.ini"


	# ---- 2/3 Disabled ----
	elif [ "${PHP_XDEBUG_ENABLE}" = "0" ]; then
		log "info" "Disabling Xdebug"
		run "sed 's/^xdebug\.remote_enable.*/xdebug.remote_enable=0/g' /etc/hhvm/php.ini"


	# ---- 3/3 Wrong value ----
	else
		log "err" "Invalid value for \$PHP_XDEBUG_ENABLE: ${PHP_XDEBUG_ENABLE}"
		log "err" "Must be '1' (for On) or '0' (for Off)"
		exit 1
	fi

fi



###
### Port forwarding
###
if ! set | grep '^FORWARD_PORTS_TO_LOCALHOST=' >/dev/null 2>&1; then
	log "warn" "\$FORWARD_PORTS_TO_LOCALHOST not set."
	log "warn" "Not ports from other machines will be forwarded to 127.0.0.1 inside this docker"
else
	# Transform into newline separated forwards:
	#   local-port:host:remote-port\n
	#   local-port:host:remote-port\n
	_forwards="$( echo "${FORWARD_PORTS_TO_LOCALHOST}" | sed 's/[[:space:]]*//g' | sed 's/,/\n/g' )"

	# loop over them
	IFS='
	'
	for forward in ${_forwards}; do
		_lport="$( echo "${forward}" | awk -F':' '{print $1}' )"
		_rhost="$( echo "${forward}" | awk -F':' '{print $2}' )"
		_rport="$( echo "${forward}" | awk -F':' '{print $3}' )"

		if ! isint "${_lport}"; then
			log "err" "Port forwarding error: local port is not an integer: ${_lport}"
			log "err" "Line: ${forward}"
			exit 1
		fi
		if ! isip "${_rhost}" && ! ishostname "${_rhost}"; then
			log "err" "Port forwarding error: remote host is not a valid IP and not a valid hostname: ${_rhost}"
			log "err" "Line: ${forward}"
			log "err" ""
			exit 1
		fi
		if ! isint "${_rport}"; then
			log "err" "Port forwarding error: remote port is not an integer: ${_rport}"
			log "err" "Line: ${forward}"
			log "err" ""
			exit 1
		fi

		log "info" "Forwarding ${_rhost}:${_rport} to 127.0.0.1:${_lport} inside this docker."
		run "/usr/bin/socat tcp-listen:${_lport},reuseaddr,fork tcp:${_rhost}:${_rport} &"
	done
fi



###
### Allow for sending emails
###
if ! set | grep '^ENABLE_MAIL=' >/dev/null 2>&1; then
	log "warn" "\$ENABLE_MAIL not set."
	log "warn" "Disabling sending of emails."
else
	if [ "${ENABLE_MAIL}" = "1" ]; then

		log "info" "Enabling sending of emails."

		# Add Mail file if it does not exist
		if [ ! -f "/var/mail/${MY_USER}" ]; then
			run "touch /var/mail/${MY_USER}"
		fi

		# Fix mail user permissions after mount
		run "chmod 0644 /var/mail/${MY_USER}"
		run "chown ${MY_USER}:${MY_GROUP} /var/mail/${MY_USER}"

		# Postfix configuration
		run "sed -i'' 's/^inet_protocols.*/inet_protocols = ipv4/g' /etc/postfix/main.cf"
		run "echo 'virtual_alias_maps = pcre:/etc/postfix/virtual' >> /etc/postfix/main.cf"
		run "echo '/.*@.*/ ${MY_USER}' >> /etc/postfix/virtual"
		run "newaliases"

		# Start Postfix
		run "postfix start"

	elif [ "${ENABLE_MAIL}" = "0" ]; then
		log "info" "Disabling sending of emails."

	else
		log "err" "Invalid value for \$ENABLE_MAIL"
		log "err" "Only 1 (for on) or 0 (for off) are allowed"
		exit 1
	fi
fi


###
### MySQL Backups
###
if ! set | grep '^MYSQL_BACKUP_USER='  >/dev/null 2>&1; then
	log "info" "\$MYSQL_BACKUP_USER not set for mysqldump-secure."
	log "info" "Keeping default user"
else
	log "info" "\$MYSQL_BACKUP_USER set for mysqldump-secure."
	log "info" "Changing to '${MYSQL_BACKUP_USER}'"
	run "sed -i'' 's/^user.*/user = ${MYSQL_BACKUP_USER}/g' /etc/mysqldump-secure.cnf"
fi
if ! set | grep '^MYSQL_BACKUP_PASS='  >/dev/null 2>&1; then
	log "info" "\$MYSQL_BACKUP_PASS not set for mysqldump-secure."
	log "info" "Keeping default password"
else
	log "info" "\$MYSQL_BACKUP_PASS set for mysqldump-secure."
	log "info" "Changing to '********'"
	run "sed -i'' 's/^password.*/password = ${MYSQL_BACKUP_PASS}/g' /etc/mysqldump-secure.cnf"
fi
if ! set | grep '^MYSQL_BACKUP_HOST='  >/dev/null 2>&1; then
	log "info" "\$MYSQL_BACKUP_HOST not set for mysqldump-secure."
	log "info" "Keeping default host"
else
	log "info" "\$MYSQL_BACKUP_HOST set for mysqldump-secure."
	log "info" "Changing to '${MYSQL_BACKUP_HOST}'"
	run "sed -i'' 's/^host.*/host = ${MYSQL_BACKUP_HOST}/g' /etc/mysqldump-secure.cnf"
fi



###
### Fix uid/gid permissions of mounted volumes
###
# Log dir
run "chown -R ${MY_USER}:${MY_GROUP} ${MY_LOG_DIR}"
run "chmod 0755 ${MY_LOG_DIR}"
run "find ${MY_LOG_DIR} -type f -exec chmod 0644 {} \;"
# HHVM dirs
run "chown -R ${MY_USER}:${MY_GROUP} /var/cache/hhvm"
run "chown -R ${MY_USER}:${MY_GROUP} /var/lib/hhvm"
run "chown -R ${MY_USER}:${MY_GROUP} /var/run/hhvm"
# Supervisor dir
run "chown -R ${MY_USER}:${MY_GROUP} /var/log/supervisor"
run "chown -R ${MY_USER}:${MY_GROUP} /var/run/supervisor"
# Home dir
run "chown -R ${MY_USER}:${MY_GROUP} /home/${MY_USER}"
# Data dir
if [ -d "/shared/httpd" ]; then
	run "chown ${MY_USER}:${MY_GROUP} /shared/httpd"
fi
# Backup dirs
run "mkdir -p /shared/backups/mysql"
run "mkdir -p /shared/backups/pgsql"
run "mkdir -p /shared/backups/mongo"
run "chown -R ${MY_USER}:${MY_GROUP} /shared/backups"
# mysqldump-secure
run "chown ${MY_USER}:${MY_GROUP} /var/log/mysqldump-secure.log"
run "chown ${MY_USER}:${MY_GROUP} /etc/mysqldump-secure.conf"
run "chown ${MY_USER}:${MY_GROUP} /etc/mysqldump-secure.cnf"



###
### Build Custom PHP config files
###
if [ -d "${MY_CFG_DIR_PHP_CUSTOM}" ]; then
	MY_FILES="$( find "${MY_CFG_DIR_PHP_CUSTOM}" -type f -iname '*.ini')"

	MY_CUSTOM_CONFIG=""
	if [ "${MY_FILES}" != "" ]; then
		for f in ${MY_FILES}; do
			MY_CUSTOM_CONFIG="${MY_CUSTOM_CONFIG} --config=${f}"
		done
	fi
	log "info" "Custom configs: ${MY_CUSTOM_CONFIG}"
	run "sed -i'' 's|^command=/usr/bin/hhvm.*|command=/usr/bin/hhvm --mode server --config=/etc/hhvm/server.ini --config=/etc/hhvm/php.ini ${MY_CUSTOM_CONFIG}|' /etc/supervisor/supervisord.conf"
fi




###
### Start
###
log "info" "Starting $( hhvm --version 2>/dev/null | grep HipHop ) via supervisord ($( supervisord -v ))"
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
