FROM php:5.6-apache
MAINTAINER Dylan Pinn <dylan@arcadiandigital.com.au>

# Install net-tools
RUN apt-get update && apt-get install net-tools -y

# Install mysqli extension
RUN docker-php-ext-install mysqli

COPY entrypoint.sh /entrypoint.sh
RUN chmod 777 /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

CMD ["apache2-foreground"]
