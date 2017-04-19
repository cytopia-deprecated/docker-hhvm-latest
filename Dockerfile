##
## HHVM
##
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
	build-date="2017-04-19"


##
## Envs
##
#ENV LTS_VERSION "-lts-3.15"
ENV LTS_VERSION ""

# User/Group
ENV MY_USER="apache"
ENV MY_GROUP="apache"
ENV MY_UID="48"
ENV MY_GID="48"

# Log files
ENV HHVM_LOG_DIR="/var/log/php-fpm"
ENV HHVM_LOG="${HHVM_LOG_DIR}/error.log"
ENV PHP_LOG_XDEBUG="${HHVM_LOG_DIR}/xdebug.log"
#ENV PHP_FPM_POOL_LOG_ERR="/var/log/php-fpm/www-error.log"
#ENV PHP_FPM_POOL_LOG_ACC="/var/log/php-fpm/www-access.log"
#ENV PHP_FPM_POOL_LOG_SLOW="/var/log/php-fpm/www-slow.log"
#ENV PHP_FPM_LOG_ERR="/var/log/php-fpm/php-fpm.err"



##
## Add User/Group
##
RUN \
  groupadd -g ${MY_GID} -r ${MY_GROUP} && \
  useradd ${MY_USER} -u ${MY_UID} -M -s /sbin/nologin -g ${MY_GROUP}



##
## Install
##

# Update system and install requirements
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
  && rm -r /var/lib/apt/lists/*



##
## Configure supervisor
## (hhvm must run in foreground)
RUN \
  mkdir -p /var/log/supervisor && \
  mkdir -p /var/run/supervisor && \
  \
  chown -R ${MY_USER}:${MY_GROUP} /var/log/supervisor && \
  chown -R ${MY_USER}:${MY_GROUP} /var/run/supervisor && \
  \
  echo "[supervisord]" > /etc/supervisor/supervisord.conf && \
  echo "logfile=/var/log/supervisor/supervisord.log" >> /etc/supervisor/supervisord.conf && \
  echo "pidfile=/var/run/supervisor/supervisord.pid" >> /etc/supervisor/supervisord.conf && \
  echo "childlogdir=/var/log/supervisor" >> /etc/supervisor/supervisord.conf && \
  echo "loglevel=info" >> /etc/supervisor/supervisord.conf && \
  echo "nodaemon=yes" >> /etc/supervisor/supervisord.conf && \
  echo "" >> /etc/supervisor/supervisord.conf && \
  echo "[program:hhvm]" >> /etc/supervisor/supervisord.conf && \
  echo "command=/usr/bin/hhvm --mode server --config=/etc/hhvm/server.ini --config=/etc/hhvm/php.ini" >> /etc/supervisor/supervisord.conf && \
  echo "autostart=true" >> /etc/supervisor/supervisord.conf && \
  echo "autorestart=true" >> /etc/supervisor/supervisord.conf && \
  echo "user=${MY_USER}" >> /etc/supervisor/supervisord.conf && \
  echo "environment=USER=\"${MY_USER}\"" >> /etc/supervisor/supervisord.conf && \
  echo "redirect_stderr=true" >> /etc/supervisor/supervisord.conf
#  echo "stdout_logfile=/dev/fd/1" >> /etc/supervisor/supervisord.conf && \
#  echo "stdout_logfile_maxbytes=0" >> /etc/supervisor/supervisord.conf && \
#  echo "directory=/var/www" >> /etc/supervisor/supervisord.conf && \



##
## Configure hhvm
## https://gist.github.com/gerard-kanters/8e1457ad4c1bbf0e5117
##
RUN \
  mkdir -p /var/cache/hhvm && \
  mkdir -p /var/lib/hhvm && \
  mkdir -p ${HHVM_LOG_DIR} && \
  mkdir -p /var/run/hhvm && \
  \
  chown -R ${MY_USER}:${MY_GROUP} /var/cache/hhvm && \
  chown -R ${MY_USER}:${MY_GROUP} ${HHVM_LOG_DIR} && \
  chown -R ${MY_USER}:${MY_GROUP} /var/lib/hhvm && \
  chown -R ${MY_USER}:${MY_GROUP} /var/run/hhvm && \
  \
  chmod 0644 /etc/hhvm/*.ini && \
  \
  touch "${HHVM_LOG}" && \
  chmod 0666 "${HHVM_LOG}" && \
  \
  touch "${PHP_LOG_XDEBUG}" && \
  chmod 0666 "${PHP_LOG_XDEBUG}" && \
  \
  echo "; hhvm options" > /etc/hhvm/server.ini && \
  echo "hhvm.server.type = fastcgi" >> /etc/hhvm/server.ini && \
  echo "hhvm.server.port = 9000" >> /etc/hhvm/server.ini && \
  echo "hhvm.server.user = ${MY_USER}" >> /etc/hhvm/server.ini && \
  echo "hhvm.php7.all = true" >> /etc/hhvm/server.ini && \
  echo "hhvm.log.level = Warning" >> /etc/hhvm/server.ini && \
  echo "hhvm.log.access_log_default_format = \"%h %l %u %t	\\\"%r\\\" %>s %b\"" >> /etc/hhvm/server.ini && \
  echo "hhvm.log.file = ${HHVM_LOG}" >> /etc/hhvm/server.ini && \
  echo "hhvm.log.always_log_unhandled_exceptions = true" >> /etc/hhvm/server.ini && \
  echo "hhvm.log.runtime_error_reporting_level = 8191" >> /etc/hhvm/server.ini && \
  echo "hhvm.log.use_log_file = true" >> /etc/hhvm/server.ini && \
  echo "hhvm.mysql.typed_results = false" >> /etc/hhvm/server.ini && \
  echo "hhvm.repo.central.path = /var/cache/hhvm/hhvm.hhbc" >> /etc/hhvm/server.ini && \
  \
  echo "; php options" > /etc/hhvm/php.ini && \
  echo "pid = /var/run/hhvm/hhvm.pid" >> /etc/hhvm/php.ini && \
  echo "date.timezone = UTC" >> /etc/hhvm/php.ini && \
  echo "session.save_handler = files" >> /etc/hhvm/php.ini && \
  echo "session.save_path = /var/lib/hhvm/sessions" >> /etc/hhvm/php.ini && \
  echo "session.gc_maxlifetime = 1440" >> /etc/hhvm/php.ini

#  echo "hhvm.server.fix_path_info = true" >> /etc/hhvm/server.ini && \


##
## Bootstrap Scipts
##
#COPY ./scripts/docker-install.sh /
COPY ./scripts/docker-entrypoint.sh /


##
## Install
##
#RUN /docker-install.sh


##
## Ports
##
EXPOSE 9000


##
## Volumes
##
VOLUME /var/log/php-fpm
VOLUME /etc/php-custom.d
VOLUME /var/mail
#
#
###
### Entrypoint
###
ENTRYPOINT ["/docker-entrypoint.sh"]
