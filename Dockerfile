ARG PHP_VERSION=7.4

FROM golang:1.18-alpine3.16 AS build-supervisord

ARG TARGETOS TARGETARCH

# Configure Go
ENV GOPATH /go
ENV PATH /go/bin:$PATH

RUN apk add --no-cache git gcc curl musl-dev && \
    mkdir -p ${GOPATH}/src ${GOPATH}/bin && \
    mkdir -p $GOPATH/src/github.com/google && \
    # Install Go Tools
    mkdir -p $GOPATH/src/golang.org/x && \
        go install -v github.com/mitchellh/gox@latest && \
        go install -v github.com/tcnksm/ghr@latest && \
    # Clone and build exporter-merger
    git clone https://github.com/ochinchina/supervisord.git $GOPATH/src/supervisord && \
        cd $GOPATH/src/supervisord && \
        git checkout c2cae38b7454d444f4cb8281d5367d50a55c0011 && \
        go generate && \
        GOOS=$TARGETOS GOARCH=$TARGETARCH \
            go build -tags release -a -ldflags "-linkmode external -extldflags -static" -o ${GOPATH}/bin/supervisord

FROM golang:1.18-alpine3.16 AS build-exporter-merger

ARG TARGETOS TARGETARCH

# Configure Go
ENV GOPATH /go
ENV PATH /go/bin:$PATH
ENV GO111MODULE=off
RUN apk add --no-cache gcc git make && \
    mkdir -p ${GOPATH}/src ${GOPATH}/bin && \
    # Install Go Tools
    go get -u golang.org/x/lint/golint && \
    go get -u github.com/golang/dep/cmd/dep && \
    # Clone and build exporter-merger
    git clone https://github.com/rebuy-de/exporter-merger.git /go/src/github.com/rebuy-de/exporter-merger/ && \
        cd /go/src/github.com/rebuy-de/exporter-merger/ && \
        git checkout v0.4.0 && \
        GOOS=$TARGETOS GOARCH=$TARGETARCH \
            make vendor && CGO_ENABLED=0 make install

FROM php:${PHP_VERSION}-fpm-alpine3.16

LABEL org.opencontainers.image.authors="Vin <vin@8sistemas.com>"

ENV EXT_REDIS_VERSION=5.3.7
ENV EXT_LIBEVENT_VERSION=3.0.6
ENV EXT_MCRYPT_VERSION=1.0.5
ENV PS1="\[\033[01;32m\]\u@\h:\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "

ARG TARGETARCH
ARG BUILD_XDEBUG=0

ARG PHP_VERSION=7.4
ARG DATABASE_MODULE=mysqli
ARG HAS_NGINX=1

# Composer
ENV COMPOSER_ALLOW_SUPERUSER=1
ENV PATH="./vendor/bin:$PATH"

# Add Docker base folders
COPY base /tmp/base

# Add Helpers
RUN if [ "$HAS_NGINX" == "1" ]; then \
        export BASE_DIRECTORY="nginx"; \
    else \
        export BASE_DIRECTORY="core"; \
    fi && \
    (cd /tmp && cp -Rp base/core/docker-php-clean base/core/supervisorctl base/core/run-with-secrets.php base/core/start-if-env-variable-is-set.sh base/core/crond.sh /usr/local/bin/) && \
    # Add a default phpinfo file
    (mkdir -p /var/www/public && cd /tmp && cp -Rp base/nginx/index.php /var/www/public/index.php) && \
    # Add Repositories
    rm -f /etc/apk/repositories && \
        (echo "http://dl-cdn.alpinelinux.org/alpine/v3.16/main" >> /etc/apk/repositories) && \
        (echo "http://dl-cdn.alpinelinux.org/alpine/v3.16/community" >> /etc/apk/repositories) && \
    # Add Build Dependencies
    if [ "$DATABASE_MODULE" == "mysqli" ]; then \
        DEV_DEPS_NAME="mariadb-connector-c-dev"; \
        DEPS_NAME="mariadb-connector-c mariadb-client"; \
    else \
        DEV_DEPS_NAME="postgresql-dev"; \
        DEPS_NAME="libpq postgresql14-client"; \
    fi && \
    apk update && apk upgrade && apk add --no-cache --virtual .build-deps  \
        zlib-dev \
        linux-headers \
        libjpeg-turbo-dev \
        libpng-dev \
        libwebp-dev \
        gettext-dev \
        oniguruma-dev \
        libxml2-dev \
        bzip2-dev \
        ${DEV_DEPS_NAME} \
        icu-dev \
        freetype-dev \
        libzip-dev \
        libevent-dev openssl-dev libmcrypt-dev \
        libxml2-dev imagemagick-dev libtool $PHPIZE_DEPS \
    # Add Production Dependencies
    && apk add --update --no-cache \
        jpegoptim \
        pngquant \
        optipng \
        nano \
        icu \
        freetype \
        ${DEPS_NAME} \
        zip libzip libevent openssl git libwebp libintl \
        oniguruma tini bash less libmcrypt sudo \
        libxml2 imagemagick \
    # Add nginx or not
    && if [ "$HAS_NGINX" == "1" ] ; then \
        apk add --no-cache nginx \
        && (curl -fsSL https://github.com/nginxinc/nginx-prometheus-exporter/releases/download/v0.11.0/nginx-prometheus-exporter_0.11.0_linux_$TARGETARCH.tar.gz | tar xvz -C /usr/bin "nginx-prometheus-exporter" ) \
        && chmod +x /usr/bin/nginx-prometheus-exporter ; \
    fi && \
    # Add Prometheus Exporter
    (curl -fsSL https://github.com/hipages/php-fpm_exporter/releases/download/v2.2.0/php-fpm_exporter_2.2.0_linux_$TARGETARCH > /usr/bin/php-fpm-exporter) && \
    # Add Composer
    (curl -fsSL https://github.com/composer/composer/releases/download/2.5.8/composer.phar > /usr/bin/composer && chmod +x /usr/bin/composer) && \
    # Configure & Install Extension
    mkdir -p /usr/src/php/ext/redis \
        && mkdir -p /usr/src/php/ext/event \
        && mkdir -p /usr/src/php/ext/mcrypt \
        && curl -fsSL https://github.com/phpredis/phpredis/archive/$EXT_REDIS_VERSION.tar.gz | tar xvz -C /usr/src/php/ext/redis --strip 1 \
        && curl -fsSL https://bitbucket.org/osmanov/pecl-event/get/$EXT_LIBEVENT_VERSION.tar.gz | tar xvz -C /usr/src/php/ext/event --strip 1 \
        && curl -fsSL https://pecl.php.net/get/mcrypt-$EXT_MCRYPT_VERSION.tgz | tar xvz -C /usr/src/php/ext/mcrypt --strip 1 \
        && docker-php-ext-configure gd --with-jpeg=/usr/include/ --with-freetype=/usr/include/ --with-webp=/usr/include \
        && if [ "$DATABASE_MODULE" == "mysqli" ]; then \
            PDO_MODULE="pdo_mysql"; \
        else PDO_MODULE="pdo_pgsql" ; \
        fi \
        && if [ "$PHP_VERSION" == "7.4" ]; then \
            EXTRA_MODULES="json"; \
        else EXTRA_MODULES=""; \
        fi \
        && docker-php-ext-install -j$(getconf _NPROCESSORS_ONLN) \
            ${DATABASE_MODULE} \
            pdo \
            ${PDO_MODULE} \
            sockets \
            ${EXTRA_MODULES} \
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
            soap \
        && docker-php-ext-install -j$(getconf _NPROCESSORS_ONLN) --ini-name zz-event.ini event && \
        (printf "\n" | pecl install imagick) && \
        docker-php-ext-enable imagick && \
        if [ "$BUILD_XDEBUG" = "1" ]; then \
            pecl install xdebug-3.1.5; \
            docker-php-ext-enable xdebug; \
        fi && \
    # Add Prometheus Exporter
    chmod +x /usr/bin/php-fpm-exporter && \
    # Use www-data as a user
    chown -R www-data:www-data /var/www \
        && addgroup www-data tty && \
    # Executable to helpers
    chmod +x /usr/local/bin/run-with-secrets.php /usr/local/bin/start-if-env-variable-is-set.sh /usr/local/bin/docker-php-clean /usr/local/bin/supervisorctl /usr/local/bin/crond.sh && \
    # Setup Crond and Supervisor by default
        # Allow all users to run crond as root
        (echo 'ALL ALL = (root) NOPASSWD: /usr/sbin/crond' > /etc/sudoers.d/crond-www-data) && \
    (echo '*  *  *  *  * /usr/local/bin/php  /var/www/artisan schedule:run >> /dev/null 2>&1' > /etc/crontabs/www-data) && mkdir /etc/supervisor.d && rm -f /etc/crontabs/root && \
    # Add PHP-FPM status and healthz endpoints
    (echo -e "[www]\npm.status_path = /orchestration/php-fpm-status\nping.path = /healthz\nping.response = alive" > /usr/local/etc/php-fpm.d/zz-status.conf) && \
    # Orchestration
    echo -e "[www]\npm.status_path = /orchestration/php-fpm-status\nping.path = /healthz\nping.response = alive" > /usr/local/etc/php-fpm.d/zz-status.conf && \
    # Remove Build Dependencies
    apk del -f .build-deps && \
        docker-php-source delete && \
    # Add PHP Config files
    (cd /tmp && \
        cp -Rp base/core/opcache.ini $PHP_INI_DIR/conf.d/ && \
        cp -Rp base/core/php.ini $PHP_INI_DIR/ \
    ) && \
    # Add supervisor basic
    (cd /tmp && cp -Rp base/${BASE_DIRECTORY}/master.ini /etc/supervisord.conf) && \
    (cd /tmp && cp -Rp base/${BASE_DIRECTORY}/supervisor.d/*.ini /etc/supervisor.d) && \
    if [ "$HAS_NGINX" == "1" ]; then \
        chown -R www-data:www-data /var/lib/nginx \
        && chown -R www-data:www-data /var/log/nginx \
        && chown -R www-data:www-data /run/nginx \
        # We need to apply 0777 permission on these directories so tmpfs and read only filesystem works
        && chmod 0777 /var/lib/nginx/tmp \
        && chmod 0777 /var/log/nginx \
        && chmod 0777 /run/nginx && \
        # Setup nginx fixes
        sed -i 's/user nginx;/user www-data;/g' /etc/nginx/nginx.conf && \
        sed -i 's/\/var\/log\/nginx\/error\.log/\/dev\/stderr/g' /etc/nginx/nginx.conf && \
        sed -i 's/\/var\/log\/nginx\/access\.log/\/dev\/stdout/g' /etc/nginx/nginx.conf && \
        mkdir /etc/nginx/conf.d && \
        # Setup nginx and php-fpm with metrics enabled
        (cd /tmp && mkdir -p /etc/nginx/http.d/ && cp -Rp base/nginx/default.conf /etc/nginx/http.d/) && \
        (cd /tmp && cp -Rp base/nginx/metrics.conf /etc/nginx/http.d/) && \
        (cd /tmp && mkdir -p /etc/nginx/snippets/ && cp -Rp base/nginx/orchestration.conf /etc/nginx/snippets/orchestration.conf) && \
        (cd /tmp && cp -Rp base/nginx/php-location-params.conf /etc/nginx/snippets/php-location-params.conf) && \
        (cd /tmp && cp -Rp base/nginx/static-files-params.conf /etc/nginx/snippets/static-files-params.conf) && \
        (cd /tmp && cp -Rp base/nginx/common-attacks-block.conf /etc/nginx/snippets/common-attacks-block.conf); \
    fi && \
    # Clean Base
    rm -rf /tmp/base

# Add Prometheus Exporter
COPY --from=build-exporter-merger /go/bin/exporter-merger /usr/bin/exporter-merger
# Add Supervisord
COPY --from=build-supervisord /go/bin/supervisord /usr/bin/supervisord

# Setup Working Dir
WORKDIR /var/www

USER www-data
EXPOSE 8080
EXPOSE 9090

ENTRYPOINT ["tini", "--", "php", "/usr/local/bin/run-with-secrets.php"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
