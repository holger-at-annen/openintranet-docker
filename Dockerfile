# ==========================================
# 1) BUILD STAGE
# ==========================================
FROM composer:2 AS build
WORKDIR /app

RUN apk add --no-cache git
RUN git clone https://git.drupalcode.org/project/openintranet.git .
RUN sed -i '/"\[3569589\] Add Service Region configuration for international SMS": "patches\/smsapi\/3569589-service-region.patch"/d' composer.json

RUN mkdir -p web/themes/custom \
 && cp -r starter-theme/ web/themes/custom/

ENV COMPOSER_NO_INTERACTION=1
RUN composer install --no-dev --ignore-platform-reqs --no-interaction

# ==========================================
# 2) RUNTIME STAGE
# ==========================================
FROM php:8.3-apache

COPY --from=build /usr/bin/composer /usr/bin/composer

RUN apt-get update && apt-get install -y \
    git curl unzip zip mariadb-client rsync \
    libpng-dev libonig-dev libxml2-dev libzip-dev \
    libjpeg-dev libfreetype6-dev libwebp-dev libavif-dev \
 && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp --with-avif \
 && docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd zip \
 && rm -rf /var/lib/apt/lists/*

RUN a2enmod rewrite
ENV APACHE_DOCUMENT_ROOT=/var/www/html/web
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf \
 && sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf
RUN printf '%s\n' \
  "<Directory ${APACHE_DOCUMENT_ROOT}>" \
  "  Options Indexes FollowSymLinks" \
  "  AllowOverride All" \
  "  Require all granted" \
  "</Directory>" \
  > /etc/apache2/conf-available/drupal.conf \
 && a2enconf drupal

# Inject PHP Memory Limits and turn ON error display
RUN printf '%s\n' \
  "memory_limit = 512M" \
  "max_execution_time = 600" \
  "output_buffering = 4096" \
  "display_errors = On" \
  "display_startup_errors = On" \
  > /usr/local/etc/php/conf.d/drupal-oi.ini

COPY --chown=www-data:www-data --from=build /app /var/www/html
WORKDIR /var/www/html

# Create a permanent system link so Apache can always find Drush
RUN ln -s /var/www/html/vendor/bin/drush /usr/local/bin/drush

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
