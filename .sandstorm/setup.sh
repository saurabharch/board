#!/bin/bash

# When you change this file, you must take manual action. Read this doc:
# - https://docs.sandstorm.io/en/latest/vagrant-spk/customizing/#setupsh

set -euo pipefail
# This is the ideal place to do things like:
#
export DEBIAN_FRONTEND=noninteractive

# switch to debian testing
cat <<EOF > /etc/apt/sources.list
#------------------------------------------------------------------------------#
#                   OFFICIAL DEBIAN REPOS
#------------------------------------------------------------------------------#

###### Debian Main Repos
deb http://deb.debian.org/debian/ testing main contrib non-free
deb-src http://deb.debian.org/debian/ testing main contrib non-free

deb http://deb.debian.org/debian/ testing-updates main contrib non-free
deb-src http://deb.debian.org/debian/ testing-updates main contrib non-free

deb http://deb.debian.org/debian-security testing/updates main
deb-src http://deb.debian.org/debian-security testing/updates main
EOF

# update os & install required packages
apt-get update
apt-get install -y curl unzip nginx php7.2-fpm php7.2-cli php7.2-curl php7.2-opcache php7.2-common php7.2-gd libpq5 php7.2-pgsql php7.2-mbstring php7.2-ldap imagemagick php-imagick php7.2-imap php7.2-xml postgresql gcc make autoconf libc-dev pkg-config php-geoip php7.2-dev libgeoip-dev

# postgresql installation
POSTGRES_DBHOST=localhost
POSTGRES_DBNAME=restyaboard
POSTGRES_DBUSER=restya
POSTGRES_DBPASS=hjVl2!rGd
POSTGRES_DBPORT=5432
PSQL_VERSION=$(psql --version | egrep -o '[0-9]{1,}' | head -1)
sed -e 's/peer/trust/g' -e 's/ident/trust/g' < /etc/postgresql/${PSQL_VERSION}/main/pg_hba.conf > /etc/postgresql/${PSQL_VERSION}/main/pg_hba.conf.1
cd /etc/postgresql/${PSQL_VERSION}/main || exit
mv pg_hba.conf pg_hba.conf_old
mv pg_hba.conf.1 pg_hba.conf
service postgresql restart

# php geoip installation
cd /opt/app

#
# I'm getting an error with wget here:
#  default: --2018-11-24 08:16:23--  https://pecl.php.net/get/geoip-1.1.1.tgz
#  default: Resolving pecl.php.net (pecl.php.net)...
#  default: 104.236.228.160
#  default: Connecting to pecl.php.net (pecl.php.net)|104.236.228.160|:443...
#  default: failed: Network is unreachable.
# That's why I downloadad all gz files and put them in the app folder
#
#wget https://pecl.php.net/get/geoip-1.1.1.tgz
tar zxvf ./geoip-1.1.1.tgz
cd geoip-1.1.1
phpize
ls -la
./configure
make
make install
echo "extension=geoip.so" >> /etc/php/7.2/fpm/php.ini
cd /opt/app
#wget http://geolite.maxmind.com/download/geoip/database/GeoLiteCountry/GeoIP.dat.gz
#gunzip GeoIP.dat.gz
#mv GeoIP.dat /usr/share/GeoIP/GeoIP.dat
#wget http://geolite.maxmind.com/download/geoip/database/GeoIPv6.dat.gz
#gunzip GeoIPv6.dat.gz
#mv GeoIPv6.dat /usr/share/GeoIP/GeoIPv6.dat
#wget http://geolite.maxmind.com/download/geoip/database/GeoLiteCity.dat.gz
#gunzip GeoLiteCity.dat.gz
#mv GeoLiteCity.dat /usr/share/GeoIP/GeoIPCity.dat
#wget http://geolite.maxmind.com/download/geoip/database/GeoLiteCityv6-beta/GeoLiteCityv6.dat.gz
#gunzip GeoLiteCityv6.dat.gz
#mv GeoLiteCityv6.dat /usr/share/GeoIP/GeoLiteCityv6.dat
#wget http://download.maxmind.com/download/geoip/database/asnum/GeoIPASNum.dat.gz
#gunzip GeoIPASNum.dat.gz
#mv GeoIPASNum.dat /usr/share/GeoIP/GeoIPASNum.dat
#wget http://download.maxmind.com/download/geoip/database/asnum/GeoIPASNumv6.dat.gz
#gunzip GeoIPASNumv6.dat.gz
#mv GeoIPASNumv6.dat /usr/share/GeoIP/GeoIPASNumv6.dat

# Restyaboard script installation
# Find latest Restyaboard version
RESTYABOARD_VERSION=$(curl --silent https://api.github.com/repos/RestyaPlatform/board/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
# Initialize directory variables
DOWNLOAD_DIR=/var/restyaboard
RESTYABOARD_DIR=/opt/app
mkdir -p ${DOWNLOAD_DIR}
curl -v -L -G -d "app=board&ver=${RESTYABOARD_VERSION}" -o /tmp/restyaboard.zip http://restya.com/download.php
unzip /tmp/restyaboard.zip -d ${DOWNLOAD_DIR}
rm /tmp/restyaboard.zip
mkdir -p ${RESTYABOARD_DIR}
cp -r ${DOWNLOAD_DIR}/* ${RESTYABOARD_DIR}
find ${RESTYABOARD_DIR} -type d -print0 | xargs -0 chmod 0755
find ${RESTYABOARD_DIR} -type f -print0 | xargs -0 chmod 0644

# Restyaboard DB creation
psql -U postgres -c "\q"
psql -U postgres -c "DROP USER IF EXISTS ${POSTGRES_DBUSER};CREATE USER ${POSTGRES_DBUSER} WITH ENCRYPTED PASSWORD '${POSTGRES_DBPASS}'"
psql -U postgres -c "CREATE DATABASE ${POSTGRES_DBNAME} OWNER ${POSTGRES_DBUSER} ENCODING 'UTF8' TEMPLATE template0"
psql -U postgres -c "CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;"
psql -U postgres -c "COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';"
psql -d ${POSTGRES_DBNAME} -f "${RESTYABOARD_DIR}/sql/restyaboard_with_empty_data.sql" -U ${POSTGRES_DBUSER}

# Restyaboard DB details update in config file
sed -i "s/^.*'R_DB_NAME'.*$/define('R_DB_NAME', '${POSTGRES_DBNAME}');/g" "${RESTYABOARD_DIR}/server/php/config.inc.php"
sed -i "s/^.*'R_DB_USER'.*$/define('R_DB_USER', '${POSTGRES_DBUSER}');/g" "${RESTYABOARD_DIR}/server/php/config.inc.php"
sed -i "s/^.*'R_DB_PASSWORD'.*$/define('R_DB_PASSWORD', '${POSTGRES_DBPASS}');/g" "${RESTYABOARD_DIR}/server/php/config.inc.php"
sed -i "s/^.*'R_DB_HOST'.*$/define('R_DB_HOST', '${POSTGRES_DBHOST}');/g" "${RESTYABOARD_DIR}/server/php/config.inc.php"
sed -i "s/^.*'R_DB_PORT'.*$/define('R_DB_PORT', '${POSTGRES_DBPORT}');/g" "${RESTYABOARD_DIR}/server/php/config.inc.php"

# Stopping Services
service php7.2-fpm stop
service nginx stop
service postgresql stop
systemctl disable php7.2-fpm
systemctl disable nginx
systemctl disable postgresql

# patch /etc/php/7.2/fpm/pool.d/www.conf to not change uid/gid to www-data
sed --in-place='' \
        --expression='s/^listen.owner = www-data/;listen.owner = www-data/' \
        --expression='s/^listen.group = www-data/;listen.group = www-data/' \
        --expression='s/^user = www-data/;user = www-data/' \
        --expression='s/^group = www-data/;group = www-data/' \
        /etc/php/7.2/fpm/pool.d/www.conf
# patch /etc/php/7.2/fpm/php-fpm.conf to not have a pidfile
sed --in-place='' \
        --expression='s/^pid =/;pid =/' \
        /etc/php/7.2/fpm/php-fpm.conf
# patch /etc/php/7.2/fpm/php-fpm.conf to place the sock file in /var
sed --in-place='' \
       --expression='s/^listen = \/run\/php\/php7.2-fpm.sock/listen = \/var\/run\/php\/php7.2-fpm.sock/' \
       /etc/php/7.2/fpm/pool.d/www.conf
# patch /etc/php/7.2/fpm/pool.d/www.conf to no clear environment variables
# so we can pass in SANDSTORM=1 to apps
sed --in-place='' \
        --expression='s/^;clear_env = no/clear_env=no/' \
        /etc/php/7.2/fpm/pool.d/www.conf
# patch timezone
timezone=$(cat /etc/timezone)
sed --in-place='' \
       --expression='s/date.timezone/;date.timezone/g' \
       /etc/php/7.2/fpm/php.ini

exit 0
