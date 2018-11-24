#!/bin/bash
set -euo pipefail

mkdir -p /var/lib/nginx
mkdir -p /var/log/nginx
mkdir -p /var/run

# Spawn mysqld, php
/usr/sbin/php-fpm7.2 --fpm-config /etc/php/7.2/fpm/php-fpm.conf -c /etc/php/7.2/fpm/php.ini
while [ ! -e /var/run/php5-fpm.sock ] ; do
    echo "waiting for php5-fpm to be available at /var/run/php5-fpm.sock"
    sleep .2
done
echo "started php-fpm. status code:" $?

/usr/sbin/nginx -g "pid /var/run/nginx.pid;"
echo "started nginx. status code:" $?

sleep infinity
