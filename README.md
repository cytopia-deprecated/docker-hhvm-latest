# HHVM latest Docker

<small>**Latest build:** 2017-08-15</small>

[![Build Status](https://travis-ci.org/cytopia/docker-hhvm-latest.svg?branch=master)](https://travis-ci.org/cytopia/docker-hhvm-latest) [![](https://images.microbadger.com/badges/version/cytopia/hhvm-latest.svg)](https://microbadger.com/images/cytopia/hhvm-latest "hhvm-latest") [![](https://images.microbadger.com/badges/image/cytopia/hhvm-latest.svg)](https://microbadger.com/images/cytopia/hhvm-latest "hhvm-latest") [![](https://images.microbadger.com/badges/license/cytopia/hhvm-latest.svg)](https://microbadger.com/images/cytopia/hhvm-latest "hhvm-latest")

[![cytopia/hhvm-latest](http://dockeri.co/image/cytopia/hhvm-latest)](https://hub.docker.com/r/cytopia/hhvm-latest/)

**[php-fpm 5.4](https://github.com/cytopia/docker-php-fpm-5.4) | [php-fpm 5.5](https://github.com/cytopia/docker-php-fpm-5.5) | [php-fpm 5.6](https://github.com/cytopia/docker-php-fpm-5.6) | [php-fpm 7.0](https://github.com/cytopia/docker-php-fpm-7.0) | [php-fpm 7.1](https://github.com/cytopia/docker-php-fpm-7.1) | [php-fpm 7.2](https://github.com/cytopia/docker-php-fpm-7.2) | hhvm-latest**

----

**HHVM latest Docker on Ubuntu**

[![Devilbox](https://raw.githubusercontent.com/cytopia/devilbox/master/.devilbox/www/htdocs/assets/img/devilbox_80.png)](https://github.com/cytopia/devilbox)

<sub>This docker image is part of the **[devilbox](https://github.com/cytopia/devilbox)**</sub>

----

## Options

**Note:** HHVM comes with `PHP 5.6` and `PHP 7` support. This container enables `PHP 7` by default. If you want to use this container with `PHP 5.6` instead, you will have to mount a custom `*.ini` file to `/etc/php-custom.d` containing the following line:
```ini
hhvm.php7.all = false
```

**Example for PHP 5.6:**
```shell
# Your local directory to be mounted
$ ls ./my-php-conf/
php-5.ini

# Contents of your local ini file
$ cat ./my-php-conf/php-5.ini
hhvm.php7.all = false

# Mount your local config into the container
$ docker run -i \
    -v ./my-php-conf:/etc/php-custom.d \
	-t cytopia/hhvm-latest
```

### Environmental variables

#### Required environmental variables

- None

#### Optional environmental variables

| Variable | Type | Default |Description |
|----------|------|---------|------------|
| DEBUG_COMPOSE_ENTRYPOINT | bool | `0` | Show shell commands executed during start.<br/>Value: `0` or `1` |
| DOCKER_LOGS_ERROR | bool | `0` | Log errors to `docker logs` instead of file inside container.<br/>Value: `0` or `1` |
| DOCKER_LOGS_XDEBUG | bool | `0` | Log php xdebug to `docker logs` instead of file inside container.<br/>Value: `0` or `1` |
| NEW_UID | integer | `1000` | Assign the default `devilbox` user a new UID. This is useful if you also want to work inside this container in order to be able to access your mounted files with the same UID. Set it to your host users uid (see `id` for your uid). |
| NEW_GID | integer | `1000` | Assign the default `devilbox` group a new GID. This is useful if you also want to work inside this container in order to be able to access your mounted files with the same GID. Set it to your host group gid (see `id` for your gid). |
| TIMEZONE | string | `UTC` | Set docker OS timezone as well as PHP timezone.<br/>(Example: `Europe/Berlin`) |
| ENABLE_MAIL | bool | `0` | Allow sending emails. Postfix will be configured for local delivery and all sent mails (even to real domains) will be catched locally. No email will ever go out. They will all be stored in a local `devilbox` account.<br/>Value: `0` or `1` |
| FORWARD_PORTS_TO_LOCALHOST | string | `` | List of remote ports to forward to `127.0.0.1`.<br/>Format: `<local-port>:<remote-host>:<remote-port>`. You can separate multiple entries by comma.<br/>Example: `3306:mysqlhost:3306, 6379:192.0.1.1:6379` |
| PHP_XDEBUG_ENABLE | bool | `0` | Enable Xdebug.<br/>Value: `0` or `1` |
| PHP_XDEBUG_REMOTE_PORT | int | `9000` | The port on your Host (where you run the IDE/editor to which xdebug should connect.) |
| PHP_XDEBUG_REMOTE_HOST | string | `` | The IP address of your Host (where you run the IDE/editor to which xdebug should connect).<br/>This is required if $PHP_DEBUG_ENABLE is turned on. |
| MYSQL_BACKUP_USER | string | mds default | Username for mysql backups used for bundled [mysqldump-secure](https://mysqldump-secure.org) |
| MYSQL_BACKUP_PASS | string | mds default | Password for mysql backups used for bundled [mysqldump-secure](https://mysqldump-secure.org) |
| MYSQL_BACKUP_HOST | string | mds default | Hostname for mysql backups used for bundled [mysqldump-secure](https://mysqldump-secure.org) |

### Default mount points

| Docker | Description |
|--------|-------------|
| /var/log/php | HHVM log dir |
| /etc/php-custom.d | Custom user configuration files. Make sure to mount this folder to your host, where you have custom `*.ini` files. |
| /var/mail | Mail mbox directory |

### Default ports

| Docker | Description |
|--------|-------------|
| 9000   | HHVM listening Port |

## Usage

It is recommended to always use the `$TIMEZONE` variable which will set php's `date.timezone`.

**1. Provide FPM port to host**
```shell
$ docker run -i \
    -p 127.0.0.1:9000:9000 \
    -e TIMEZONE=Europe/Berlin \
    -t cytopia/hhvm-latest
```

**2. Overwrite php.ini settings**

Mount a PHP config directory from your host into the PHP docker in order to overwrite php.ini settings.
```shell
$ docker run -i \
    -v ~/.etc/php.d:/etc/php-custom.d \
    -p 127.0.0.1:9000:9000 \
    -e TIMEZONE=Europe/Berlin \
    -t cytopia/hhvm-latest
```


**3. MySQL connect via 127.0.0.1 (via port-forward)**

Forward MySQL Port from `172.168.0.30` (or any other IP address/hostname) and Port `3306` to the PHP docker on `127.0.0.1:3306`. By this, your PHP files inside the docker can use `127.0.0.1` to connect to a MySQL database.
```shell
$ docker run -i \
    -p 127.0.0.1:9000:9000 \
    -e TIMEZONE=Europe/Berlin \
    -e FORWARD_PORTS_TO_LOCALHOST='3306:172.168.0.30:3306' \
    -t cytopia/hhvm-latest
```

**4. MySQL and Redis connect via 127.0.0.1 (via port-forward)**

Forward MySQL Port from `172.168.0.30:3306` and Redis port from `redis:6379` to the PHP docker on `127.0.0.1:3306` and `127.0.0.1:6379`. By this, your PHP files inside the docker can use `127.0.0.1` to connect to a MySQL or Redis database.
```shell
$ docker run -i \
    -p 127.0.0.1:9000:9000 \
    -e TIMEZONE=Europe/Berlin \
    -e FORWARD_PORTS_TO_LOCALHOST='3306:172.168.0.30:3306, 6379:redis:6379' \
    -t cytopia/hhvm-latest
```

**5. MySQL connect via localhost (via socket mount)**

Mount a MySQL socket from `~/run/mysqld/mysqld.sock` (on your host) into the PHP docker to `/tmp/mysql/mysqld.sock`.
By this, your PHP files inside the docker can use `localhost` to connect to a MySQL database.
In order to make php aware of new path of the mysql socket, we will also have to create a php config file and mount it into the container.

```shell
# Show local custom php config
$ cat ~/tmp/cfg/php/my-config.ini
mysql.default_socket = /tmp/mysql/mysqld.sock
mysqli.default_socket = /tmp/mysql/mysqld.sock
pdo_mysql.default_socket = /tmp/mysql/mysqld.sock

# Start container with mounted socket and config
$ docker run -i \
    -v ~/run/mysqld:/tmp/mysql \
    -v ~/tmp/cfg/php:/etc/php-custom.d \
    -p 127.0.0.1:9000:9000 \
    -e TIMEZONE=Europe/Berlin \
    -t cytopia/hhvm-latest
```


**6. Launch Postfix for mail-catching**

Once you `$ENABLE_MAIL=1`, all mails sent via any of your PHP applications no matter to which domain, are catched locally into the `devilbox` account. You can also mount the mail directory locally to hook in with `mutt` and read those mails.
```shell
$ docker run -i \
    -p 127.0.0.1:9000:9000 \
    -v /tmp/mail:/var/mail \
    -e TIMEZONE=Europe/Berlin \
    -e ENABLE_MAIL=1 \
    -t cytopia/hhvm-latest
```

**7. Run with webserver that supports PHP-FPM**

`~/my-host-www` will be the directory that serves the php files (your document root).
Make sure to mount it into both, php and the webserver.

```shell
# Start myself
$ docker run -d \
    -p 9000 \
    -v ~/my-host-www:/var/www/html \
    --name php \
    -t cytopia/hhvm-latest

# Start webserver and link into myself
$ docker run -d \
    -p 80:80 \
    -v ~/my-host-www:/var/www/html \
    -e PHP_FPM_ENABLE=1 \
    -e PHP_FPM_SERVER_ADDR=php \
    -e PHP_FPM_SERVER_PORT=9000 \
    --link php \
    -t cytopia/nginx-mainline
```

## Modules

**[Version]**

HipHop VM 3.21.0 (rel)

**[HHVM Modules]**

apc, assert, bcmath, brotli, curl, date, highlight, hphp, imagick, intl, mbstring, memcache, memcached, mongodb, mysqli, pcre, session, xdebug, zend, zlib

**[Tools]**

| tool           | version |
|----------------|---------|
| [awesome-ci](https://github.com/cytopia/awesome-ci)  | 0.9 |
| [composer](https://getcomposer.org)    | 1.5.1 |
| [drupal-console](https://drupalconsole.com) | unavailable |
| [drush](http://www.drush.org)          | 8.1.12 |
| [git](https://git-scm.com)             | 2.7.4 |
| [laravel installer](https://github.com/laravel/installer)     | 1.3.7 |
| [mysqldump-secure](https://mysqldump-secure.org) | 0.16.3 |
| [node](https://nodejs.org)             | 6.11.2 |
| [npm](https://www.npmjs.com)           | 3.10.10 |
| [phalcon-devtools](https://github.com/phalcon/phalcon-devtools)   | unavailable |
| [symfony installer](https://github.com/symfony/symfony-installer) | 10 |
| [wp-cli](https://wp-cli.org)           | 1.3.0 |

**[Misc Tools]**

mongodump, mongoexport, mongofiles, mongoimport, mongooplog, mongoperf, mongorestore, mongostat, mongotop, mysql, mysqladmin, mysqlanalyze, mysqlcheck, mysql_config_editor, mysqldump, mysqldumpslow, mysql_embedded, mysqlimport, mysqloptimize, mysqlpump, mysqlrepair, mysqlreport, mysqlshow, mysqlslap, pg_basebackup, pg_dump, pg_dumpall, pg_isready, pg_receivewal, pg_receivexlog, pg_recvlogical, pg_restore, psql
