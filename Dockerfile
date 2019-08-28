FROM phusion/baseimage:0.11
LABEL maintainer="dylan@arcadiandigital.com.au"

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]
ENV DEBIAN_FRONTEND noninteractive
RUN locale-gen en_AU.utf8
ENV LANG=en_AU.utf8

RUN add-apt-repository ppa:ondrej/php -y

RUN apt-get update \
    && apt-get install -y \
    nginx php7.2 php7.2-fpm php7.2-cli php7.2-mysql php7.2-curl php7.2-gd \
    libpng-dev libjpeg-dev ca-certificates tar wget \
    php7.2-xmlrpc imagemagick php7.2-imagick zip \
    php7.2-xml php7.2-zip \
    php7.2-mbstring php7.2-dom python-pip python-dev git libyaml-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN pip install awscli

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

# Configure PHP
RUN sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/7.2/fpm/php.ini
RUN sed -i "s/;date.timezone =.*/date.timezone = Australia\/Melbourne/" /etc/php/7.2/fpm/php.ini
RUN sed -i "s/upload_max_filesize =.*/upload_max_filesize = 32M/g" /etc/php/7.2/fpm/php.ini
RUN sed -i "s/; max_input_vars =.*/max_input_vars = 10000/" /etc/php/7.2/fpm/php.ini
RUN sed -i "s/post_max_size =.*/post_max_size = 32M/g" /etc/php/7.2/fpm/php.ini
RUN sed -i "s/max_execution_time =.*/max_execution_time = 300/g" /etc/php/7.2/fpm/php.ini
RUN sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php/7.2/fpm/php-fpm.conf
RUN sed -i "s/error_log = \/var\/log\/php5-fpm.log/error_log = syslog/" /etc/php/7.2/fpm/php-fpm.conf
RUN sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/7.2/cli/php.ini
RUN sed -i "s/;date.timezone =.*/date.timezone = Australia\/Melbourne/" /etc/php/7.2/cli/php.ini
RUN sed -i "s/;clear_env = no/clear_env = no/" /etc/php/7.2/fpm/pool.d/www.conf
RUN sed -i "s/;request_terminate_timeout =.*/request_terminate_timeout = 300/g" /etc/php/7.2/fpm/pool.d/www.conf
# Fix Upload errror
RUN sed -i "s/;upload_tmp_dir =*/upload_tmp_dir = \/tmp\//" /etc/php/7.2/fpm/php.ini
RUN chmod -R 777 /tmp/

# HACK: This fixes unable to bind listening socket for address '/run/php/php7.2-fpm.sock': No such file or directory
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
