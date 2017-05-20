###
### HHVM
###
FROM ubuntu:xenial
MAINTAINER "cytopia" <cytopia@everythingcli.org>


##
## Labels
##
LABEL \
	name="cytopia's HHVM latest Image" \
	image="hhvm-latest" \
	vendor="cytopia" \
	license="MIT" \
	build-date="2017-05-20"


###
### Envs
###
#ENV LTS_VERSION "-lts-3.15"
ENV LTS_VERSION ""

# User/Group
ENV MY_USER="devilbox" \
	MY_GROUP="devilbox" \
	MY_UID="1000" \
	MY_GID="1000"

# User PHP config directories
ENV MY_CFG_DIR_PHP_CUSTOM="/etc/php-custom.d"

# Log Files
ENV MY_LOG_DIR="/var/log/php" \
	MY_LOG_FILE_XDEBUG="/var/log/php/xdebug.log" \
	MY_LOG_FILE_ERR="/var/log/php/www-error.log"


###
### Install
###
RUN \
	groupadd -g ${MY_GID} -r ${MY_GROUP} && \
	useradd -u ${MY_UID} -m -s /bin/bash -g ${MY_GROUP} ${MY_USER}

RUN apt-get update && apt-get -y install \
	software-properties-common \
	debian-archive-keyring \
	&& rm -r /var/lib/apt/lists/*

# Add repository and keys
RUN apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0x5a16e7281be7a449
RUN add-apt-repository "deb http://dl.hhvm.com/ubuntu $(lsb_release -sc)${LTS_VERSION} main"

# Install packages
RUN apt-get update && apt-get -y install \
	hhvm \
	supervisor \
	postfix \
	postfix-pcre \
	socat \
	tzdata \
	dnsutils \
	iputils-ping \
	&& rm -r /var/lib/apt/lists/*


###
### Install Tools
###
RUN apt-get update && apt-get -y install \
	curl \
	git \
	wget \
	&& rm -r /var/lib/apt/lists/*

RUN \
	mkdir -p /usr/local/src && \
	chown ${MY_USER}:${MY_GROUP} /usr/local/src && \
	VERSION="$( curl -Lq https://nodejs.org 2>/dev/null | grep LTS | grep -Eo 'data-version.*.' | grep -oE 'v[0-9.]+' )" && \
	wget -P /usr/local/src https://nodejs.org/dist/${VERSION}/node-${VERSION}-linux-x64.tar.xz && \
	tar xvf /usr/local/src/node-${VERSION}-linux-x64.tar.xz -C /usr/local/src && \
	ln -s /usr/local/src/node-${VERSION}-linux-x64 /usr/local/node && \
	ln -s /usr/local/node/bin/* /usr/local/bin/ && \
	rm -f /usr/local/src/node-${VERSION}-linux-x64.tar.xz


RUN \
	curl -sS https://getcomposer.org/installer | php && \
	mv composer.phar /usr/local/bin/composer

RUN \
	mkdir -p /usr/local/src && \
	chown ${MY_USER}:${MY_GROUP} /usr/local/src && \
	su - ${MY_USER} -c 'git clone https://github.com/drush-ops/drush.git /usr/local/src/drush' && \
	su - ${MY_USER} -c 'cd /usr/local/src/drush && git checkout 8.1.11' && \
	su - ${MY_USER} -c 'cd /usr/local/src/drush && composer install --no-interaction --no-progress' && \
	ln -s /usr/local/src/drush/drush /usr/local/bin/drush


###
### Configure postfix
###
RUN \
	sed -i'' 's/^myhostname.*/#myhostname = php/g' /etc/postfix/main.cf


###
### Configure supervisor
### (hhvm must run in foreground)
RUN \
	mkdir -p /var/log/supervisor && \
	mkdir -p /var/run/supervisor && \
	\
	chown -R ${MY_USER}:${MY_GROUP} /var/log/supervisor && \
	chown -R ${MY_USER}:${MY_GROUP} /var/run/supervisor && \
	\
	( \
		echo "[supervisord]"; \
		echo "logfile=/var/log/supervisor/supervisord.log"; \
		echo "pidfile=/var/run/supervisor/supervisord.pid"; \
		echo "childlogdir=/var/log/supervisor"; \
		echo "loglevel=info"; \
		echo "nodaemon=yes"; \
		echo ""; \
		\
		echo "[program:hhvm]"; \
		echo "command=/usr/bin/hhvm --mode server --config=/etc/hhvm/server.ini --config=/etc/hhvm/php.ini"; \
		echo "autostart=true"; \
		echo "autorestart=true"; \
		echo "user=${MY_USER}"; \
		echo "environment=USER=\"${MY_USER}\""; \
		echo "redirect_stderr=true"; \
	) > /etc/supervisor/supervisord.conf
# echo "stdout_logfile=/dev/fd/1" >> /etc/supervisor/supervisord.conf && \
# echo "stdout_logfile_maxbytes=0" >> /etc/supervisor/supervisord.conf && \


###
### Configure hhvm
### https://gist.github.com/gerard-kanters/8e1457ad4c1bbf0e5117
RUN \
	mkdir -p ${MY_LOG_DIR} && \
	mkdir -p /var/cache/hhvm && \
	mkdir -p /var/lib/hhvm && \
	mkdir -p /var/run/hhvm && \
	\
	chown -R ${MY_USER}:${MY_GROUP} ${MY_LOG_DIR} && \
	chown -R ${MY_USER}:${MY_GROUP} /var/cache/hhvm && \
	chown -R ${MY_USER}:${MY_GROUP} /var/lib/hhvm && \
	chown -R ${MY_USER}:${MY_GROUP} /var/run/hhvm && \
	\
	chmod 0644 /etc/hhvm/*.ini && \
	\
	touch "${MY_LOG_FILE_ERR}" && \
	chmod 0666 "${MY_LOG_FILE_ERR}" && \
	\
	touch "${MY_LOG_FILE_XDEBUG}" && \
	chmod 0666 "${MY_LOG_FILE_XDEBUG}" && \
	\
	( \
		echo "; hhvm options"; \
		echo "hhvm.server.type = fastcgi"; \
		echo "hhvm.server.port = 9000"; \
		echo "hhvm.server.user = ${MY_USER}"; \
		echo "hhvm.php7.all = true"; \
		echo "hhvm.log.level = Warning"; \
		echo "hhvm.log.access_log_default_format = \"%h %l %u %t	\\\"%r\\\" %>s %b\""; \
		echo "hhvm.log.file = ${MY_LOG_FILE_ERR}"; \
		echo "hhvm.log.always_log_unhandled_exceptions = true"; \
		echo "hhvm.log.runtime_error_reporting_level = 8191"; \
		echo "hhvm.log.use_log_file = true"; \
		echo "hhvm.mysql.typed_results = false"; \
		echo "hhvm.repo.central.path = /var/cache/hhvm/hhvm.hhbc"; \
	) > /etc/hhvm/server.ini && \
	\
	( \
		echo "; php options"; \
		echo "pid = /var/run/hhvm/hhvm.pid"; \
		echo "date.timezone = UTC"; \
		echo "session.save_handler = files"; \
		echo "session.save_path = /var/lib/hhvm/sessions"; \
		echo "session.gc_maxlifetime = 1440"; \
	) > /etc/hhvm/php.ini
# echo "hhvm.server.fix_path_info = true" >> /etc/hhvm/server.ini && \


###
### Bootstrap Scipts
###
COPY ./scripts/docker-entrypoint.sh /
COPY ./scripts/bash-profile /etc/bash_profile


###
### Ports
###
EXPOSE 9000


###
### Volumes
###
VOLUME /var/log/php
VOLUME /etc/php-custom.d
VOLUME /var/mail


###
### Entrypoint
###
ENTRYPOINT ["/docker-entrypoint.sh"]
