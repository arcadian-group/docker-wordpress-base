FROM phusion/baseimage:0.9.18
MAINTAINER Dylan Pinn <dylan@arcadiandigital.com.au>

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]
ENV DEBIAN_FRONTEND noninteractive
RUN locale-gen en_AU.utf8
ENV LANG=en_AU.utf8

RUN add-apt-repository ppa:ondrej/php5-5.6 -y

RUN apt-get update \
    && apt-get install -y --force-yes \
    nginx php5 php5-fpm php5-cli php5-mysql php5-curl php5-gd \
    libpng12-dev libjpeg-dev ca-certificates tar wget

RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Define rancher compose version
ENV RANCHER_COMPOSE_VERSION v0.7.4

# Download and install rancher compose
RUN wget -O /tmp/rancher-compose-linux-amd64-${RANCHER_COMPOSE_VERSION}.tar.gz "https://github.com/rancher/rancher-compose/releases/download/${RANCHER_COMPOSE_VERSION}/rancher-compose-linux-amd64-${RANCHER_COMPOSE_VERSION}.tar.gz" \
  && tar -xf /tmp/rancher-compose-linux-amd64-${RANCHER_COMPOSE_VERSION}.tar.gz -C /tmp \
  && mv /tmp/rancher-compose-${RANCHER_COMPOSE_VERSION}/rancher-compose /usr/local/bin/rancher-compose \
  && rm -R /tmp/rancher-compose-linux-amd64-${RANCHER_COMPOSE_VERSION}.tar.gz /tmp/rancher-compose-${RANCHER_COMPOSE_VERSION}\
  && chmod +x /usr/local/bin/rancher-compose

# Add WP-CLI
RUN curl -L https://raw.github.com/wp-cli/builds/gh-pages/phar/wp-cli.phar > wp-cli.phar;\
  chmod +x wp-cli.phar;\
  mv wp-cli.phar /usr/bin/wp

# Configure nginx
RUN echo "daemon off;" >> /etc/nginx/nginx.conf
RUN sed -i "s/sendfile on/sendfile off/" /etc/nginx/nginx.conf
ADD build/nginx/default /etc/nginx/sites-available/default

# Configure PHP
RUN sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php5/fpm/php.ini
RUN sed -i "s/;date.timezone =.*/date.timezone = Australia\/Melbourne/" /etc/php5/fpm/php.ini
RUN sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php5/fpm/php-fpm.conf
RUN sed -i "s/error_log = \/var\/log\/php5-fpm.log/error_log = syslog/" /etc/php5/fpm/php-fpm.conf
RUN sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php5/cli/php.ini
RUN sed -i "s/;date.timezone =.*/date.timezone = Australia\/Melbourne/" /etc/php5/cli/php.ini
RUN sed -i "s/;clear_env = no/clear_env = no/" /etc/php5/fpm/pool.d/www.conf
# Fix Upload errror
RUN sed -i "s/;upload_tmp_dir =*/upload_tmp_dir = \/tmp\//" /etc/php5/fpm/php.ini
RUN chmod -R 777 /tmp/

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

EXPOSE 80
