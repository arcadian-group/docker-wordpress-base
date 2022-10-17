FROM phusion/baseimage:focal-1.0.0
LABEL maintainer="sean@arcadiandigital.com.au"

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]
ENV DEBIAN_FRONTEND noninteractive
RUN locale-gen en_AU.utf8
ENV LANG=en_AU.utf8

RUN add-apt-repository ppa:ondrej/php -y

RUN apt-get update \
    && apt-get install -y \
    nginx php8.0 php8.0-fpm php8.0-cli php8.0-mysql php8.0-curl php8.0-gd \
    libpng-dev libjpeg-dev ca-certificates tar wget \
    php8.0-xmlrpc imagemagick php8.0-imagick zip \
    php8.0-xml php8.0-zip \
    php8.0-mbstring php8.0-dom python3-pip python3-dev git libyaml-dev \
    memcached php8.0-memcache libpcre3-dev uuid-dev libssl-dev libxml2-dev libgd-dev libxslt1-dev sudo \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-2.0.30.zip" -o "awscliv2.zip"

RUN unzip awscliv2.zip

RUN ./aws/install

# Add WP-CLI
RUN curl -L https://raw.github.com/wp-cli/builds/gh-pages/phar/wp-cli.phar > wp-cli.phar;\
  chmod +x wp-cli.phar;\
  mv wp-cli.phar /usr/bin/wp
RUN echo 'alias wp="wp --allow-root"' >>  ~/.bashrc

# Add Composer
WORKDIR /root
ADD install-composer.sh /root/install-composer.sh
RUN /root/install-composer.sh
RUN mv /root/composer.phar /usr/local/bin/composer

# Configure nginx
RUN echo "daemon off;" >> /etc/nginx/nginx.conf
RUN sed -i "s/sendfile on/sendfile off/" /etc/nginx/nginx.conf
ADD build/nginx/default /etc/nginx/sites-available/default
ADD build/nginx/uploads.conf /etc/nginx/conf.d/uploads.conf
ADD build/nginx/global /etc/nginx/global
ADD build/nginx/modules-available /etc/nginx/modules-available
ADD install-ngx-pagespeed.sh /root/install-ngx-pagespeed.sh
RUN /root/install-ngx-pagespeed.sh
RUN mkdir /var/ngx_pagespeed_cache; chown -R www-data:www-data /var/ngx_pagespeed_cache

# Configure PHP
RUN sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/8.0/fpm/php.ini
RUN sed -i "s/;date.timezone =.*/date.timezone = Australia\/Melbourne/" /etc/php/8.0/fpm/php.ini
RUN sed -i "s/upload_max_filesize =.*/upload_max_filesize = 32M/g" /etc/php/8.0/fpm/php.ini
RUN sed -i "s/; max_input_vars =.*/max_input_vars = 10000/" /etc/php/8.0/fpm/php.ini
RUN sed -i "s/post_max_size =.*/post_max_size = 32M/g" /etc/php/8.0/fpm/php.ini
RUN sed -i "s/max_execution_time =.*/max_execution_time = 300/g" /etc/php/8.0/fpm/php.ini
RUN sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php/8.0/fpm/php-fpm.conf
RUN sed -i "s/error_log = \/var\/log\/php5-fpm.log/error_log = syslog/" /etc/php/8.0/fpm/php-fpm.conf
RUN sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/8.0/cli/php.ini
RUN sed -i "s/;date.timezone =.*/date.timezone = Australia\/Melbourne/" /etc/php/8.0/cli/php.ini
RUN sed -i "s/;clear_env = no/clear_env = no/" /etc/php/8.0/fpm/pool.d/www.conf
RUN sed -i "s/;request_terminate_timeout =.*/request_terminate_timeout = 300/g" /etc/php/8.0/fpm/pool.d/www.conf
# Fix Upload errror
RUN sed -i "s/;upload_tmp_dir =*/upload_tmp_dir = \/tmp\//" /etc/php/8.0/fpm/php.ini
RUN echo 'opcache.jit_buffer_size=50M' >> /etc/php/8.0/cli/conf.d/10-opcache.ini
RUN chmod -R 777 /tmp/

# HACK: This fixes unable to bind listening socket for address '/run/php/php8.0-fpm.sock': No such file or directory
RUN mkdir /run/php

# Add nginx service
RUN mkdir /etc/service/nginx
ADD build/nginx/run.sh /etc/service/nginx/run
RUN chmod +x /etc/service/nginx/run

# Add PHP service
RUN mkdir /etc/service/phpfpm
ADD build/php/run.sh /etc/service/phpfpm/run
RUN chmod +x /etc/service/phpfpm/run

WORKDIR /var/www/html
RUN chown -R www-data:www-data /var/www/html
ADD fix-wordpress-permissions.sh /var/www/fix-perms.sh

EXPOSE 80

# Add HEALTHCHECK for sites.
HEALTHCHECK --interval=5m --timeout=3s \
  CMD curl -f http://localhost/ || exit 1
