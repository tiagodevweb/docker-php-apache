FROM php:7.4.26-apache-buster

# 1. Install development packages and clean up apt cache.
RUN apt-get update && apt-get install -y \
    curl \
    g++ \
    git \
    libbz2-dev \
    libfreetype6-dev \
    libicu-dev \
    libjpeg-dev \
    libmcrypt-dev \
    libpng-dev \
    libreadline-dev \
    libzip-dev \
    libonig-dev \
    sudo \
    unzip \
    zip && \
    apt-get clean autoclean && \
    apt-get autoremove -y && \
    rm -rf /var/lib/{apt,dpkg,cache,log}/

# 2. Apache configs + document root.
ENV SERVER_NAME=localhost
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
RUN echo "ServerName ${SERVER_NAME}" >> /etc/apache2/apache2.conf && \
    sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf && \
    sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

# 3. mod_rewrite for URL rewrite and mod_headers for .htaccess extra headers like Access-Control-Allow-Origin-
RUN a2enmod rewrite headers

# 4. Start with base PHP config, then add extensions.
RUN mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"
COPY php/override.ini "$PHP_INI_DIR/conf.d/override.ini"

RUN docker-php-ext-install \
    bcmath \
    bz2 \
    calendar \
    iconv \
    intl \
    mbstring \
    opcache \
    pdo_mysql \
    zip && \
    docker-php-ext-configure gd && \
    docker-php-ext-install -j$(nproc) gd && \
    docker-php-source delete

# 5. Composer.
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# 6. Create new user userapp which will be running inside the container
# it will have www-data as a secondary group and will sync with the same 1000 id set inside out .env file
ARG uid=1000
RUN useradd -u ${uid} -g www-data -m -s /bin/bash userapp
USER userapp

# 7. Test if container is still working.
HEALTHCHECK --interval=60s --timeout=30s CMD nc -zv localhost 80 || exit 1
