FROM php:8.0-fpm-alpine3.14

LABEL org.opencontainers.image.authors="Kashyap Merai <kashyapk62@gmail.com>, Vin <vin@8sistemas.com>"

ENV EXT_REDIS_VERSION=5.3.7
ENV EXT_LIBEVENT_VERSION=3.0.6
ENV EXT_MCRYPT_VERSION=1.0.5
ENV PS1="\[\033[01;32m\]\u@\h:\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "

ARG TARGETARCH
ARG BUILD_XDEBUG=0

# Composer
ENV COMPOSER_ALLOW_SUPERUSER=1
ENV PATH="./vendor/bin:$PATH"

# Add Docker base folders
COPY base /tmp/base

# Add Helpers
RUN (cd /tmp && cp -Rp base/core/docker-php-clean base/core/supervisorctl base/core/run-with-secrets.php base/core/start-if-env-variable-is-set.sh /usr/local/bin/) && \
    # Add Repositories
    rm -f /etc/apk/repositories &&\
        (echo "http://dl-cdn.alpinelinux.org/alpine/v3.14/main" >> /etc/apk/repositories) && \
        (echo "http://dl-cdn.alpinelinux.org/alpine/v3.14/community" >> /etc/apk/repositories) && \
    # Add Build Dependencies
    apk update && apk upgrade && apk add --no-cache --virtual .build-deps  \
        zlib-dev \
        libjpeg-turbo-dev \
        libpng-dev \
        libwebp-dev \
        gettext-dev \
        oniguruma-dev \
        libxml2-dev \
        bzip2-dev \
        postgresql-dev \
        icu-dev \
        freetype-dev \
        libzip-dev libevent-dev openssl-dev libmcrypt-dev && \
    # Add Production Dependencies
    apk add --update --no-cache \
        jpegoptim \
        pngquant \
        optipng \
        nano \
        icu \
        freetype \
        libpq \
        zip \
        libzip libevent openssl git libwebp libintl oniguruma tini bash less libmcrypt && \
    # Add Prometheus Exporter
    (curl -fsSL https://github.com/hipages/php-fpm_exporter/releases/download/v2.2.0/php-fpm_exporter_2.2.0_linux_$TARGETARCH > /usr/bin/php-fpm-exporter) && \
    # Add Composer
    (curl -fsSL https://github.com/composer/composer/releases/download/2.3.5/composer.phar > /usr/bin/composer && chmod +x /usr/bin/composer) && \
    # Add supervisor static
    if [ "$TARGETARCH" == "amd64" ]; then \
        curl -fsSL https://github.com/ochinchina/supervisord/releases/download/v0.7.3/supervisord_0.7.3_Linux_64-bit.tar.gz | tar xvz -C /usr/bin --wildcards --strip 1 "*/supervisord"; \
    else \
        curl -fsSL https://github.com/ochinchina/supervisord/releases/download/v0.7.3/supervisord_0.7.3_Linux_ARM64.tar.gz | tar xvz -C /usr/bin --wildcards --strip 1 "*/supervisord"; \
    fi && \
    chmod +x /usr/bin/supervisord && \
    # Configure & Install Extension
    mkdir -p /usr/src/php/ext/redis \
        && mkdir -p /usr/src/php/ext/event \
        && mkdir -p /usr/src/php/ext/mcrypt \
        && curl -fsSL https://github.com/phpredis/phpredis/archive/$EXT_REDIS_VERSION.tar.gz | tar xvz -C /usr/src/php/ext/redis --strip 1 \
        && curl -fsSL https://bitbucket.org/osmanov/pecl-event/get/$EXT_LIBEVENT_VERSION.tar.gz | tar xvz -C /usr/src/php/ext/event --strip 1 \
        && curl -fsSL https://pecl.php.net/get/mcrypt-$EXT_MCRYPT_VERSION.tgz | tar xvz -C /usr/src/php/ext/mcrypt --strip 1 \
        && docker-php-ext-configure gd --with-jpeg=/usr/include/ --with-freetype=/usr/include/ --with-webp=/usr/include \
        && docker-php-ext-install -j$(getconf _NPROCESSORS_ONLN) \
            mysqli \
            pdo_pgsql \
            sockets \
            intl \
            gd \
            xml \
            bz2 \
            pcntl \
            bcmath \
            exif \
            zip \
            gettext \
            mbstring \
            redis \
            mcrypt \
            calendar \
        && docker-php-ext-install -j$(getconf _NPROCESSORS_ONLN) --ini-name zz-event.ini event && \
        if [ "$BUILD_XDEBUG" = "1" ]; then \
            apk add --no-cache --virtual .build-deps-xdebug $PHPIZE_DEPS; \
            pecl install xdebug-3.1.5; \
            docker-php-ext-enable xdebug; \
            apk del -f .build-deps-xdebug; \
        fi && \
    # Add Prometheus Exporter
    chmod +x /usr/bin/php-fpm-exporter && \
    # Executable to helpers
    chmod +x /usr/local/bin/run-with-secrets.php /usr/local/bin/start-if-env-variable-is-set.sh /usr/local/bin/docker-php-clean /usr/local/bin/supervisorctl && \
    # Use www-data as a user
    chown -R www-data:www-data /var/www && \
    # Setup Crond and Supervisor by default
    (echo '*  *  *  *  * /usr/local/bin/php  /var/www/artisan schedule:run >> /dev/null 2>&1' > /etc/crontabs/www-data) && mkdir /etc/supervisor.d && rm -f /etc/crontabs/root && \
    # Add PHP-FPM status and healthz endpoints
    (echo -e "[www]\npm.status_path = /orchestration/php-fpm-status\nping.path = /healthz\nping.response = alive" > /usr/local/etc/php-fpm.d/zz-status.conf) && \
    # Remove Build Dependencies
    apk del -f .build-deps && \
        docker-php-source delete && \
    # Add PHP Config files
    (cd /tmp && \
        cp -Rp base/core/opcache.ini $PHP_INI_DIR/conf.d/ && \
        cp -Rp base/core/php.ini $PHP_INI_DIR/ \
    ) && \
    # Add supervisor basic
    (cd /tmp && cp -Rp base/core/master.ini /etc/supervisord.conf) && \
    (cd /tmp && cp -Rp base/core/supervisor.d/*.ini /etc/supervisor.d) && \
    # Clean Base
    rm -rf /tmp/base

# Setup Working Dir
WORKDIR /var/www

USER www-data
EXPOSE 9000
EXPOSE 9090

ENTRYPOINT ["tini", "--", "php", "/usr/local/bin/run-with-secrets.php"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
