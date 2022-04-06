# laravel-alpine

**Forked from kamerk22/laravel-alpine**

Laravel PHP framework running on PHP-FPM with alpine base Docker Image 🐳

![SIZE](http://i.imgur.com/oJ4jCPP.jpg)

## Pull it from Docker Registry

To pull the docker image:

```bash
docker pull ghcr.io/eightsystems/laravel-alpine:8.0-mysql
```

## Usage

To run from current dir

```bash
docker run -v $(pwd):/var/www ghcr.io/eightsystems/laravel-alpine:8.0-mysql "composer install --prefer-dist"
```

## What's Included

- [Composer](https://getcomposer.org/) ( v2 - from Docker official image )
- CRON ( pre-installed and configured to work with Laravel Scheduler )
- [Supervisor](http://supervisord.org)
- ARM64 version

## Other Details

- Alpine base image

## PHP Extension

- opcache
- pdo
- mysqli (mysql images)
- pdo_mysql (mysql images)
- pgsql (pgsql images)
- pdo_pgsql (pgsql images)
- sockets
- json (except for PHP 8.0 as it's builtin)
- intl
- gd
- xml
- bz2
- pcntl
- bcmath
- exif
- zip
- redis
- event

## Adding other PHP Extension

You can add additional PHP Extensions by running `docker-ext-install` command. Don't forget to install necessary dependencies for required extension.

```bash
FROM ghcr.io/eightsystems/laravel-alpine:8.0-mysql
RUN docker-php-ext-install memcached
```

## Adding custom CRON

```bash
FROM ghcr.io/eightsystems/laravel-alpine:8.0-mysql
echo '0 * * ? * * /usr/local/bin/php  /var/www/artisan schedule:run >> /dev/null 2>&1' > /etc/crontabs/root
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
user=forge
redirect_stderr=true
stdout_logfile=/var/www/storage/logs/horizon.log
```

On your Docker image

```bash
FROM ghcr.io/eightsystems/laravel-alpine:8.0-mysql
ADD horizon.ini /etc/supervisor.d/
```

For more details on config http://supervisord.org/configuration.html

## Troubleshooting / Issues / Contributing

Feel free to open an issue in this repository.
