FROM php:5.6-fpm
MAINTAINER Dylan Pinn <dylan@arcadiandigital.com.au>

# Install mysqli extension
RUN docker-php-ext-install mysqli

# COPY entrypoint.sh /entrypoint.sh
# RUN chmod 777 /entrypoint.sh
# ENTRYPOINT ["/entrypoint.sh"]

# CMD ["apache2-foreground"]
