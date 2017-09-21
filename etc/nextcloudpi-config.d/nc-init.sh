#!/bin/bash

# Init NextCloud database and perform initial configuration
#
# Copyleft 2017 by Ignacio Nunez Hernanz <nacho _a_t_ ownyourbits _d_o_t_ com>
# GPL licensed (see end of file) * Use at your own risk!
#
# Usage:
# 
#   ./installer.sh nc-init.sh <IP> (<img>)
#
# See installer.sh instructions for details
#
# More at https://ownyourbits.com/2017/02/13/nextcloud-ready-raspberry-pi-image/
#

ADMINUSER_=admin
ADMINPASS_=ownyourbits
DBADMIN=ncadmin
DESCRIPTION="(Re)initiate Nextcloud to a clean configuration"

INFOTITLE="Clean NextCloud configuration"
INFO="This action will configure NextCloud to NextCloudPi defaults.

** YOUR CONFIGURATION WILL BE LOST **

"

configure()
{
  ## RE-CREATE DATABASE TABLE 

  echo "Setting up database..."

  # wait for mariadb
  pgrep -x mysqld &>/dev/null || { echo "mariaDB process not found"; return 1; }

  while :; do
    [[ -S /var/run/mysqld/mysqld.sock ]] && break
    sleep 0.5
  done

  # workaround to emulate DROP USER IF EXISTS ..;)
  local DBPASSWD=$( grep password /root/.my.cnf | cut -d= -f2 )
  mysql -u root <<EOF
DROP DATABASE IF EXISTS nextcloud;
CREATE DATABASE nextcloud
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;
GRANT USAGE ON *.* TO '$DBADMIN'@'localhost' IDENTIFIED BY '$DBPASSWD';
DROP USER '$DBADMIN'@'localhost';
CREATE USER '$DBADMIN'@'localhost' IDENTIFIED BY '$DBPASSWD';
GRANT ALL PRIVILEGES ON nextcloud.* TO $DBADMIN@localhost;
EXIT
EOF

  ## INITIALIZE NEXTCLOUD

  echo "Setting up Nextcloud..."

  cd /var/www/nextcloud/
  rm -f config/config.php
  sudo -u www-data php occ maintenance:install --database \
    "mysql" --database-name "nextcloud"  --database-user "$DBADMIN" --database-pass \
    "$DBPASSWD" --admin-user "$ADMINUSER_" --admin-pass "$ADMINPASS_"

  # cron jobs
  sudo -u www-data php occ background:cron

  # ACPu cache
  sed -i '$i\ \ '\''memcache.local'\'' => '\''\\\\OC\\\\Memcache\\\\APCu'\'',' /var/www/nextcloud/config/config.php

  # 4 Byte UTF8 support
  sudo -u www-data php occ config:system:set mysql.utf8mb4 --type boolean --value="true"

  # Default trusted domain ( only from nextcloudpi-config )
  test -f /usr/local/bin/nextcloud-domain.sh && bash /usr/local/bin/nextcloud-domain.sh
  sudo -u www-data php occ config:system:set trusted_domains 5 --value="nextcloudpi.local"

  # email
  sudo -u www-data php occ config:system:set mail_smtpmode     --value="php"
  sudo -u www-data php occ config:system:set mail_smtpauthtype --value="LOGIN"
  sudo -u www-data php occ config:system:set mail_from_address --value="admin"
  sudo -u www-data php occ config:system:set mail_domain       --value="ownyourbits.com"

  # other
  sudo -u www-data php occ config:system:set overwriteprotocol --value=https
}

install(){ :; }
cleanup()  { :; }

# License
#
# This script is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This script is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this script; if not, write to the
# Free Software Foundation, Inc., 59 Temple Place, Suite 330,
# Boston, MA  02111-1307  USA
