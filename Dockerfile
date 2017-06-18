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
	build-date="2017-06-18"


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
	wget \
	&& rm -r /var/lib/apt/lists/*

# Add repository and keys
RUN \
	apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0x5a16e7281be7a449 && \
	add-apt-repository "deb http://dl.hhvm.com/ubuntu $(lsb_release -sc)${LTS_VERSION} main" && \
	wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
	add-apt-repository "deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main" && \
	apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv EA312927 && \
	echo "deb http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.2 multiverse" > /etc/apt/sources.list.d/mongodb-org-3.2.list


# Install packages
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y install \
	hhvm \
	hhvm-dev \
	libtool \
	git \
	supervisor \
	postfix \
	postfix-pcre \
	socat \
	tzdata \
	dnsutils \
	iputils-ping \
	&& rm -r /var/lib/apt/lists/*

# Install MongoDB for HHVM
RUN \
	mkdir -p /usr/local/src && \
	git clone https://github.com/mongodb/mongo-hhvm-driver.git /usr/local/src/mongo-hhvm-driver && \
	cd /usr/local/src/mongo-hhvm-driver && \
	git submodule sync && git submodule update --init --recursive && \
	hphpize && \
	cmake . && \
	make configlib && \
	make && \
	make install && \
	rm -rf /usr/local/src/mongo-hhvm-driver


###
### Install Tools
###
RUN apt-get update && apt-get -y install \
	mysql-client \
	postgresql-client-9.6 \
	mongodb-org-tools \
	curl \
	git \
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
	mv composer.phar /usr/local/bin/composer && \
	composer self-update

RUN \
	DRUSH_VERSION="$( curl -q https://api.github.com/repos/drush-ops/drush/releases 2>/dev/null | grep tag_name | grep -Eo '\"[0-9.]+\"' | head -1 | sed 's/\"//g' )" && \
	mkdir -p /usr/local/src && \
	chown ${MY_USER}:${MY_GROUP} /usr/local/src && \
	su - ${MY_USER} -c 'git clone https://github.com/drush-ops/drush.git /usr/local/src/drush' && \
	v="${DRUSH_VERSION}" su ${MY_USER} -p -c 'cd /usr/local/src/drush && git checkout ${v}' && \
	su - ${MY_USER} -c 'cd /usr/local/src/drush && composer install --no-interaction --no-progress' && \
	ln -s /usr/local/src/drush/drush /usr/local/bin/drush

RUN \
	composer create-project drupal/console /usr/local/src/drupal-console --no-dev && \
	chmod +x /usr/local/src/drupal-console/bin/drupal && \
	ln -s /usr/local/src/drupal-console/bin/drupal /usr/local/bin/drupal

RUN \
	composer create-project wp-cli/wp-cli /usr/local/src/wp-cli --no-dev && \
	chmod +x /usr/local/src/wp-cli/bin/wp && \
	ln -s /usr/local/src/wp-cli/bin/wp /usr/local/bin/wp

RUN \
	mkdir -p /usr/local/src && \
	chown ${MY_USER}:${MY_GROUP} /usr/local/src && \
	su - ${MY_USER} -c 'git clone https://github.com/cytopia/mysqldump-secure.git /usr/local/src/mysqldump-secure' && \
	su - ${MY_USER} -c 'cd /usr/local/src/mysqldump-secure && git checkout $(git describe --abbrev=0 --tags)' && \
	ln -s /usr/local/src/mysqldump-secure/bin/mysqldump-secure /usr/local/bin && \
	cp /usr/local/src/mysqldump-secure/etc/mysqldump-secure.conf /etc && \
	cp /usr/local/src/mysqldump-secure/etc/mysqldump-secure.cnf /etc && \
	touch /var/log/mysqldump-secure.log && \
	chown ${MY_USER}:${MY_GROUP} /etc/mysqldump-secure.* && \
	chown ${MY_USER}:${MY_GROUP} /var/log/mysqldump-secure.log && \
	chmod 0400 /etc/mysqldump-secure.conf && \
	chmod 0400 /etc/mysqldump-secure.cnf && \
	chmod 0644 /var/log/mysqldump-secure.log && \
	sed -i'' 's/^DUMP_DIR=.*/DUMP_DIR="\/shared\/backups\/mysql"/g' /etc/mysqldump-secure.conf && \
	sed -i'' 's/^DUMP_DIR_CHMOD=.*/DUMP_DIR_CHMOD="0755"/g' /etc/mysqldump-secure.conf && \
	sed -i'' 's/^DUMP_FILE_CHMOD=.*/DUMP_FILE_CHMOD="0644"/g' /etc/mysqldump-secure.conf && \
	sed -i'' 's/^LOG_CHMOD=.*/LOG_CHMOD="0644"/g' /etc/mysqldump-secure.conf && \
	sed -i'' 's/^NAGIOS_LOG=.*/NAGIOS_LOG=0/g' /etc/mysqldump-secure.conf


###
### Cleanup
###
RUN apt-get update && apt-get -y remove \
	hhvm-dev \
	libtool \
	&& apt-get autoremove -y \
	&& rm -r /var/lib/apt/lists/*


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
		echo "hhvm.php7.all = true"; \
		\
		echo "hhvm.server.type = fastcgi"; \
		echo "hhvm.server.port = 9000"; \
		echo "hhvm.server.user = ${MY_USER}"; \
		echo "hhvm.server.implicit_flush = 1"; \
		\
		echo "hhvm.log.level = Warning"; \
		echo "hhvm.log.access_log_default_format = \"%h %l %u %t	\\\"%r\\\" %>s %b\""; \
		echo "hhvm.log.use_log_file = true"; \
		echo "hhvm.log.file = ${MY_LOG_FILE_ERR}"; \
		echo "hhvm.log.always_log_unhandled_exceptions = true"; \
		echo "hhvm.log.runtime_error_reporting_level = 8191"; \
		\
		echo "hhvm.debug.full_backtrace = true"; \
		echo "hhvm.debug.server_stack_trace = true"; \
		echo "hhvm.debug.server_error_message = true"; \
		echo "hhvm.debug.translate_source = true"; \
		\
		echo "hhvm.error_handling.call_user_handler_on_fatals = 1"; \
		\
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
		echo "hhvm.dynamic_extension_path =  $(dirname $( find /usr/lib/x86_64-linux-gnu/hhvm/extensions/ -name mongodb.so | head -1 ))"; \
		echo "hhvm.dynamic_extensions[mongodb]=mongodb.so"; \
	) > /etc/hhvm/php.ini
# echo "hhvm.server.fix_path_info = true" >> /etc/hhvm/server.ini && \


###
### Configure PS1
###
RUN \
	echo ". /etc/bash_profile" >> /home/${MY_USER}/.bashrc && \
	echo ". /etc/bash_profile" >> /root/.bashrc


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
