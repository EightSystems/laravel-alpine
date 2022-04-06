FROM php:8.0-fpm-alpine3.14

LABEL org.opencontainers.image.authors="Kashyap Merai <kashyapk62@gmail.com>, Vin <vin@8sistemas.com>"

ENV EXT_REDIS_VERSION=5.3.7
ENV EXT_LIBEVENT_VERSION=3.0.6

# Add Repositories
RUN rm -f /etc/apk/repositories &&\
    echo "http://dl-cdn.alpinelinux.org/alpine/v3.14/main" >> /etc/apk/repositories && \
    echo "http://dl-cdn.alpinelinux.org/alpine/v3.14/community" >> /etc/apk/repositories

# Add Build Dependencies
RUN apk update && apk add --no-cache --virtual .build-deps  \
    zlib-dev \
    libjpeg-turbo-dev \
    libpng-dev \
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
    libzip libevent openssl git

# Configure & Install Extension
RUN mkdir -p /usr/src/php/ext/redis \
    && mkdir -p /usr/src/php/ext/event \
    && curl -fsSL https://github.com/phpredis/phpredis/archive/$EXT_REDIS_VERSION.tar.gz | tar xvz -C /usr/src/php/ext/redis --strip 1 \
    && curl -fsSL https://bitbucket.org/osmanov/pecl-event/get/$EXT_LIBEVENT_VERSION.tar.gz | tar xvz -C /usr/src/php/ext/event --strip 1 \
    && docker-php-ext-configure opcache --enable-opcache \
    && docker-php-ext-configure gd --with-jpeg=/usr/include/ --with-freetype=/usr/include/ \
    && docker-php-ext-install \
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
    && docker-php-ext-install redis \
    && docker-php-ext-install --ini-name zz-event.ini event

# Add Composer
COPY --from=composer /usr/bin/composer /usr/bin/composer
ENV COMPOSER_ALLOW_SUPERUSER=1
ENV PATH="./vendor/bin:$PATH"

COPY opcache.ini $PHP_INI_DIR/conf.d/
COPY php.ini $PHP_INI_DIR/conf.d/

# Setup Crond and Supervisor by default
RUN echo '*  *  *  *  * /usr/local/bin/php  /var/www/artisan schedule:run >> /dev/null 2>&1' > /etc/crontabs/root && mkdir /etc/supervisor.d
ADD master.ini /etc/supervisor.d/
ADD default.conf /etc/nginx/http.d/
RUN sed -i 's/user nginx;/user www-data;/g' /etc/nginx/nginx.conf

# Remove Build Dependencies
RUN apk del -f .build-deps && \
    docker-php-source delete

# Setup Working Dir
WORKDIR /var/www

CMD ["/usr/bin/supervisord"]
