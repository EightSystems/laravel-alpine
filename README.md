# laravel-alpine

**Forked from kamerk22/laravel-alpine**

Laravel PHP framework running on PHP-FPM with alpine base Docker Image 🐳

![SIZE](https://github.com/EightSystems/laravel-alpine/blob/master/image-list-screenshot.png?raw=true)

## Registry Options

You can either pull it from ghcr (Github Container Registry) or DockerHub Registry

- **GHCR Image:** ghcr.io/eightsystems/laravel-alpine
- **DockerHub Image:** 8sistemas/laravel-alpine

## Available versions/tags

You can use any of the versions-tag bellow in the following form:

`version-tag` as in: `8.4-alpine3.20-mysql-nginx`

| Version        | Tags                                                                                                       | Notes       |
| -------------- | ---------------------------------------------------------------------------------------------------------- | ----------- |
| 7.4-alpine3.16 | mysql, mysql-nginx, pgsql, pgsql-nginx, mysql-xdebug, mysql-nginx-xdebug, pgsql-xdebug, pgsql-nginx-xdebug | Alpine 3.16 |
| 8.0-alpine3.16 | mysql, mysql-nginx, pgsql, pgsql-nginx, mysql-xdebug, mysql-nginx-xdebug, pgsql-xdebug, pgsql-nginx-xdebug | Alpine 3.16 |
| 8.1-alpine3.16 | mysql, mysql-nginx, pgsql, pgsql-nginx, mysql-xdebug, mysql-nginx-xdebug, pgsql-xdebug, pgsql-nginx-xdebug | Alpine 3.16 |
| 8.2-alpine3.16 | mysql, mysql-nginx, pgsql, pgsql-nginx, mysql-xdebug, mysql-nginx-xdebug, pgsql-xdebug, pgsql-nginx-xdebug | Alpine 3.16 |
| 8.3-alpine3.20 | mysql, mysql-nginx, pgsql, pgsql-nginx, mysql-xdebug, mysql-nginx-xdebug, pgsql-xdebug, pgsql-nginx-xdebug | Alpine 3.20 |
| 8.4-alpine3.20 | mysql, mysql-nginx, pgsql, pgsql-nginx, mysql-xdebug, mysql-nginx-xdebug, pgsql-xdebug, pgsql-nginx-xdebug | Alpine 3.20 |

## Pull it from Docker Registry

To pull the docker image:

```bash
docker pull 8sistemas/laravel-alpine:8.3-alpine3.20-mysql
```

## Usage

To run from current dir

```bash
docker run -v $(pwd):/var/www 8sistemas/laravel-alpine:8.3-alpine3.20-mysql "composer install --prefer-dist"
```

## What's Included

- [Composer](https://getcomposer.org/) (v2 - from Docker official image)
- CRON (pre-installed and configured to work with Laravel Scheduler)
- [Go port of Supervisor](https://github.com/ochinchina/supervisord)
  - See details in [Supervisord.md](https://github.com/EightSystems/laravel-alpine/blob/master/docs/Supervisord.md)
- ARM64 version
- Nginx "modular" config. See [NGINX-Files.md](https://github.com/EightSystems/laravel-alpine/blob/master/docs/NGINX-Files.md)
- Prometheus exporter for both PHP and NGINX (if you enable it setting the env variable `ENABLE_PROMETHEUS_EXPORTER_RUNNER=1`). See [Prometheus-Scrapper.md](https://github.com/EightSystems/laravel-alpine/blob/master/docs/Prometheus-Scrapper.md)
  - We have the php-fpm_exporter running by default at 9090, and the nginx prometheus exporter at 9190.
    - nginx-prometheus-exporter:0.10
    - php-fpm_exporter:2.0.4
- Secrets Manager Environment Expander
  - See [Secrets-Environment-Expander.md](https://github.com/EightSystems/laravel-alpine/blob/master/docs/Secrets-Environment-Expander.md)
- Changing users/group UID and GID
  - This helps when your containers need to connect with some shared NFS server and you need to match the UID/GID.
  - See [Change-User-Uid-And-Gid.md](https://github.com/EightSystems/laravel-alpine/blob/master/docs/Change-User-Uid-And-Gid.md)
- PHP Production ini values
  - See [php.ini](https://github.com/EightSystems/laravel-alpine/blob/master/base/core/php.ini)
- Opcache Support
  - See [opcache.ini](https://github.com/EightSystems/laravel-alpine/blob/master/base/core/opcache.ini)
- Able to run with drop all privileges running as `www-data` (linux uid 82, gid 82) user
- Small memory footprint
  - 8.1-alpine3.16-mysql-nginx with Prometheus Exporter enabled uses ~65MB of RAM when idle
    - This allows you to run your container with as little of 128MB of RAM still giving some room for your application.
- Readonly filesystem support (with some paths needed being tmpfs)
  - [Sample Docker-compose file](https://github.com/EightSystems/laravel-alpine/blob/master/8.4/docker-compose.yaml)
  - [Sample Kubernetes POD Yaml](https://github.com/EightSystems/laravel-alpine/blob/master/8.4/kube-pod.yaml)

## Other Details

- Alpine base image 3.16 and 3.20
- Uses DockerHub php base image
- Security Scan enabled on a biweekly basis (using Anchore)
- Supervisor has `supervisorctl` support enabled on all tags

## PHP Extensions

These extensions are the basics (and some small additions) needed to run Laravel version 8.x and up

- pdo
- mysqli (mysql images)
- pdo_mysql (mysql images)
- pgsql (pgsql images)
- pdo_pgsql (pgsql images)
- sockets
- json (except for PHP 8.0+ as it's builtin)
- intl
- xml
- bz2
- pcntl
- bcmath
- exif
- zip
- redis
- event
- calendar
- imagick
- soap
- gmp

### Small additions

- opcache
- gettext
- mbstring
- mcrypt (< 8.4)
- gd (with jpeg, png, freetype, gif, and webp support)
- XDebug (with the `-xdebug` tags)

## Adding other PHP Extension

You can add additional PHP Extensions by running `docker-ext-install` command. Don't forget to install necessary dependencies for required extension.

```Dockerfile
FROM 8sistemas/laravel-alpine:8.4-alpine3.20-mysql
USER root
RUN docker-php-ext-install memcached
USER www-data
```

## Adding custom CRON

```Dockerfile
FROM 8sistemas/laravel-alpine:8.4-alpine3.20-mysql
RUN echo '* * * * * /usr/local/bin/php  /var/www/artisan another:command >> /dev/null 2>&1' >> /etc/crontabs/www-data
```

## Adding custom Supervisor config

You can add your own Supervisor config inside `/etc/supervisor.d/` for Laravel Queue or Laravel Horizon. File extension needs to be `*.ini`. By default this image added `php-fpm` and `crond` process in supervisor.

E.g: For Laravel Horizon make file `horizon.ini`

```ini
[program:horizon]
process_name=%(program_name)s
command=php /var/www/artisan horizon
autostart=true
autorestart=true
user=www-data
redirect_stderr=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
```

On your Docker image

```Dockerfile
FROM 8sistemas/laravel-alpine:8.4-alpine3.20-mysql
USER root
ADD horizon.ini /etc/supervisor.d/
USER www-data
```

For more details on supervisor config http://supervisord.org/configuration.html

## Docker capabilities

You can basically drop all the capabilities as you can see in the example docker-compose, and kube files, but we do need the `setuid` and `setgid` capabitilies to be able to run `CRON`, if you remove these capabilities please also disable cron in supervisor with a simple `rm -f /etc/supervisor.d/01_crond.ini` inside your `Dockerfile`.

For `CRON` to run we need to use `sudo` to elevate our privileges to root even though the container run as `www-data (82)` by default.
So we added a simple `/etc/sudoers.d/crond-www-data` with the following content:

```
ALL ALL = (root) NOPASSWD: /usr/sbin/crond'
```

This allows any user to run the `crond` command, even though `sudo` is bad, this was we prevent wide open access.

## Troubleshooting / Issues / Contributing

Feel free to open an issue in this [GitHub repository](https://github.com/eightsystems/laravel-alpine).
