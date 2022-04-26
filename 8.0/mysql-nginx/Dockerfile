FROM golang:1.18.1-alpine3.14 AS build-exporter-merger

RUN apk add --no-cache git make

# Configure Go
ENV GOPATH /go
ENV PATH /go/bin:$PATH
ENV GO111MODULE=off
RUN mkdir -p ${GOPATH}/src ${GOPATH}/bin

# Install Go Tools
RUN go get -u golang.org/x/lint/golint
RUN go get -u github.com/golang/dep/cmd/dep

RUN git clone https://github.com/rebuy-de/exporter-merger.git /go/src/github.com/rebuy-de/exporter-merger/ && \
    cd /go/src/github.com/rebuy-de/exporter-merger/ && \
    git checkout v0.4.0 && \
    make vendor && CGO_ENABLED=0 make install

FROM php:8.0-fpm-alpine3.14

ARG TARGETARCH

LABEL org.opencontainers.image.authors="Kashyap Merai <kashyapk62@gmail.com>, Vin <vin@8sistemas.com>"

ENV EXT_REDIS_VERSION=5.3.7
ENV EXT_LIBEVENT_VERSION=3.0.6

# Add Repositories
RUN rm -f /etc/apk/repositories &&\
    echo "http://dl-cdn.alpinelinux.org/alpine/v3.14/main" >> /etc/apk/repositories && \
    echo "http://dl-cdn.alpinelinux.org/alpine/v3.14/community" >> /etc/apk/repositories

# Add Build Dependencies
RUN apk update && apk upgrade && apk add --no-cache --virtual .build-deps  \
    zlib-dev \
    libjpeg-turbo-dev \
    libpng-dev \
    libwebp-dev \
    gettext-dev \
    oniguruma-dev \
    libxml2-dev \
    bzip2-dev \
    zip libevent-dev openssl-dev

# Add Production Dependencies
RUN apk add --update --no-cache \
    jpegoptim \
    pngquant \
    optipng \
    supervisor \
    nano \
    icu-dev \
    freetype-dev \
    nginx \
    mysql-client \
    libzip-dev \
    libzip libevent openssl git libwebp libintl oniguruma tini bash

# Configure & Install Extension
RUN mkdir -p /usr/src/php/ext/redis \
    && mkdir -p /usr/src/php/ext/event \
    && curl -fsSL https://github.com/phpredis/phpredis/archive/$EXT_REDIS_VERSION.tar.gz | tar xvz -C /usr/src/php/ext/redis --strip 1 \
    && curl -fsSL https://bitbucket.org/osmanov/pecl-event/get/$EXT_LIBEVENT_VERSION.tar.gz | tar xvz -C /usr/src/php/ext/event --strip 1 \
    && docker-php-ext-configure opcache --enable-opcache \
    && docker-php-ext-configure gd --with-jpeg=/usr/include/ --with-freetype=/usr/include/ --with-webp=/usr/include \
    && docker-php-ext-install -j$(getconf _NPROCESSORS_ONLN) \
    opcache \
    mysqli \
    pdo \
    pdo_mysql \
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
    && docker-php-ext-install -j$(getconf _NPROCESSORS_ONLN) redis \
    && docker-php-ext-install -j$(getconf _NPROCESSORS_ONLN) --ini-name zz-event.ini event

# Add Prometheus Exporter
COPY --from=nginx/nginx-prometheus-exporter:0.10 /usr/bin/nginx-prometheus-exporter /usr/bin/nginx-prometheus-exporter
ADD https://github.com/hipages/php-fpm_exporter/releases/download/v2.0.4/php-fpm_exporter_2.0.4_linux_$TARGETARCH /usr/bin/php-fpm-exporter
RUN chmod +x /usr/bin/php-fpm-exporter
COPY --from=build-exporter-merger /go/bin/exporter-merger /usr/bin/exporter-merger

# Add Composer
COPY --from=composer /usr/bin/composer /usr/bin/composer
ENV COMPOSER_ALLOW_SUPERUSER=1
ENV PATH="./vendor/bin:$PATH"

COPY base/core/run-with-secrets.php /usr/local/bin/run-with-secrets.php
COPY base/core/start-if-env-variable-is-set.sh /usr/local/bin/start-if-env-variable-is-set.sh
RUN chmod +x /usr/local/bin/run-with-secrets.php /usr/local/bin/start-if-env-variable-is-set.sh

COPY base/core/opcache.ini $PHP_INI_DIR/conf.d/
COPY base/core/php.ini $PHP_INI_DIR/conf.d/

# Add a default phpinfo file
COPY base/nginx/index.php /var/www/public/index.php

# Use www-data as a user
RUN chown -R www-data:www-data /var/www \
    && chown -R www-data:www-data /var/lib/nginx \
    && chown -R www-data:www-data /var/log/nginx \
    && chown -R www-data:www-data /run/nginx \
# We need to apply 0777 permission on these directories so tmpfs and read only filesystem works
    && chmod 0777 /var/lib/nginx/tmp \
    && chmod 0777 /var/log/nginx \
    && chmod 0777 /run/nginx

# Setup Crond and Supervisor by default
RUN echo '*  *  *  *  * /usr/local/bin/php  /var/www/artisan schedule:run >> /dev/null 2>&1' > /etc/crontabs/www-data && mkdir /etc/supervisor.d && rm -f /etc/crontabs/root
ADD base/nginx/master.ini /etc/supervisord.conf

# Setup nginx and php-fpm with metrics enabled
ADD base/nginx/default.conf /etc/nginx/http.d/
ADD base/nginx/metrics.conf /etc/nginx/http.d/
ADD base/nginx/orchestration.conf /etc/nginx/snippets/orchestration.conf
ADD base/nginx/php-location-params.conf /etc/nginx/snippets/php-location-params.conf
ADD base/nginx/static-files-params.conf /etc/nginx/snippets/static-files-params.conf
ADD base/nginx/common-attacks-block.conf /etc/nginx/snippets/common-attacks-block.conf

RUN sed -i 's/user nginx;/user www-data;/g' /etc/nginx/nginx.conf \
    && sed -i 's/\/var\/log\/nginx\/error\.log/\/dev\/stderr/g' /etc/nginx/nginx.conf \
    && sed -i 's/\/var\/log\/nginx\/access\.log/\/dev\/stdout/g' /etc/nginx/nginx.conf \
    && mkdir /etc/nginx/conf.d

RUN echo -e "[www]\npm.status_path = /orchestration/php-fpm-status\nping.path = /healthz\nping.response = alive" > /usr/local/etc/php-fpm.d/zz-status.conf

# Remove Build Dependencies
RUN apk del -f .build-deps && \
    docker-php-source delete

# Setup Working Dir
WORKDIR /var/www

USER www-data
EXPOSE 8080
EXPOSE 9090

ENTRYPOINT ["tini", "--"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
