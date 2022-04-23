FROM php:7.4-fpm-alpine3.14

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
    postgresql-dev \ 
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
    postgresql-client \ 
    libzip-dev \
    libzip libevent openssl git libwebp libintl oniguruma tini

# Configure & Install Extension
RUN mkdir -p /usr/src/php/ext/redis \
    && mkdir -p /usr/src/php/ext/event \
    && curl -fsSL https://github.com/phpredis/phpredis/archive/$EXT_REDIS_VERSION.tar.gz | tar xvz -C /usr/src/php/ext/redis --strip 1 \
    && curl -fsSL https://bitbucket.org/osmanov/pecl-event/get/$EXT_LIBEVENT_VERSION.tar.gz | tar xvz -C /usr/src/php/ext/event --strip 1 \
    && docker-php-ext-configure opcache --enable-opcache \
    && docker-php-ext-configure gd --with-jpeg=/usr/include/ --with-freetype=/usr/include/ --with-webp=/usr/include \
    && docker-php-ext-configure pgsql -with-pgsql=/usr/local/pgsql \
    && docker-php-ext-install -j$(getconf _NPROCESSORS_ONLN) \
    opcache \
    pdo_pgsql \
    pgsql \
    pdo \
    sockets \
    json \
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

# Add Composer
COPY --from=composer /usr/bin/composer /usr/bin/composer
ENV COMPOSER_ALLOW_SUPERUSER=1
ENV PATH="./vendor/bin:$PATH"

COPY opcache.ini $PHP_INI_DIR/conf.d/
COPY php.ini $PHP_INI_DIR/conf.d/

# Use www-data as a user
RUN chown -R www-data:www-data /var/www

# Setup Crond and Supervisor by default
RUN echo '*  *  *  *  * /usr/local/bin/php  /var/www/artisan schedule:run >> /dev/null 2>&1' > /etc/crontabs/www-data && mkdir /etc/supervisor.d && rm -f /etc/crontabs/root
ADD master.ini /etc/supervisord.conf

# Remove Build Dependencies
RUN apk del -f .build-deps && \
    docker-php-source delete

# Setup Working Dir
WORKDIR /var/www

USER www-data

ENTRYPOINT ["tini", "--"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]