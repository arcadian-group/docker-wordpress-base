#!/bin/bash

chown -R www-data:www-data .
export DOCKER_HOST_IP=$(route -n | awk '/UG[ \t]/{print $2}')

exec "$@"
