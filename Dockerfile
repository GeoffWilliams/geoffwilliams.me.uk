FROM php:7.3.6-apache-stretch
RUN apt-get update && apt-get install -y \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libmcrypt-dev \
        libpng-dev \
        libzip-dev \
        sendmail \
    && docker-php-ext-install -j$(nproc) zip \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install -j$(nproc) gd
VOLUME ["/var/www/html/"]
# enable .htaccess
RUN sed -i '/<Directory \/var\/www\/>/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf
# mod_rewrite on
RUN a2enmod rewrite
RUN usermod -u 1000 www-data
#RUN adduser --disabled-password --gecos '' developer

# turn on failing on errors to match production
RUN echo "error_reporting=E_ALL" > /usr/local/etc/php/conf.d/error_reporting.ini
RUN echo "display_errors = On" > /usr/local/etc/php/conf.d/display_errors.ini