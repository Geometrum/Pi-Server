#!/bin/bash
source incl/include.sh

apt-get -y upgrade
apt-get -y dist-upgrade
apt-get -y install -f
apt-get -y autoremove

apt-get -y install apache2 mysql-server libapache2-mod-php7.0
apt-get -y install php7.0-gd php7.0-json php7.0-mysql php7.0-curl php7.0-mbstring
apt-get -y install php7.0-intl php7.0-mcrypt php-imagick php7.0-xml php7.0-zip

sed -i "s~^#c~~g" $apache_available_dir/local.conf

echo -e "
<Directory /var/www/cloud/html/>
  Options Indexes FollowSymlinks
  AllowOverride All
  Require all granted

 <IfModule mod_dav.c>
  Dav off
 </IfModule>

 Satisfy Any
 SetEnv HOME /var/www/cloud/html
 SetEnv HTTP_HOME /var/www/cloud/html

</Directory>" >> $apache_config_file

$add_user_file $nextcloud_name

wget https://download.nextcloud.com/server/releases/latest.zip
wget https://download.nextcloud.com/server/releases/latest.zip.sh512
sha512 -c latest.zip.sh512 < latest.zip
unzip latest.zip
rm latest.zip*
mv nextcloud $nextcloud_dir
rm -rf $www_dir/$nextcloud_name/html
ln -s $nextcloud_dir $www_dir/$nextcloud_name/html

chown -R $nextcloud_name:$nextcloud_name $nextcloud_dir

a2enmod headers
a2enmod env
a2enmod dir
a2enmod mime

echo -e "

Creation of your Nextcloud directory
"
read -sp "Tape a pass for your admin account $cloud_admin: " adminPass
read -sp "Tape a pass to allow Nextcloud to be connected on mysql with $cloud_user user: " pass
echo -e "

Root password (mysql)"
mysql -u root -e "FLUSH PRIVILEGES; CREATE USER \"$cloud_user\"@localhost IDENTIFIED BY \"$pass\"; CREATE DATABASE $nextcloud_name; GRANT ALL PRIVILEGES ON $nextcloud_name.* TO \"$cloud_user\"@localhost;" -p

sudo -u www-data php $nextcloud_dir/occ maintenance:install --database "mysql" --database-name "$nextcloud_name" --database-user "$cloud_user" --database-pass "$pass" --admin-user "$cloud_admin" --admin-pass "$adminPass"

sed -i "s~0 => 'localhost',~0 => '$nextcloud_name.$server_domain.$server_tld',\
    1 => '$local_ip',\
    2 => 'localhost',~" $nextcloud_dir/config/config.php

sed -i "s~'overwrite.cli.url' => 'http://localhost',~'overwrite.cli.url' => 'https://$nextcloud_name.$server_domain.$server_tld',\
    'htaccess.RewriteBase' => '/',~" $nextcloud_dir/config/config.php

ln -s $nextcloud_dir/data/nextcloud.log $www_dir/$nextcloud_name/log/

sudo -u www-data php $nextcloud_dir/occ maintenance:update:htaccess

rm -rf $apache_enabled_dir/*

systemctl daemon-reload
/etc/init.d/apache2 restart
/etc/init.d/php7.0-fpm restart

echo -e "

Installation complited
Your website contains two files: one to test Apache2, the second to prompt PHP infos
Go to localhost/phpmyadmin, $server_name/phpmyadmin, $local_ip/phpmyadmin, 127.0.0.1/phpmyadmin to access to PhpMyAdmin
cloud.$server_domain.$server_tld redirect to the cloud but before, you have to set Nextcloud parameters going to localhost/$nextcloud_name
All requests via internet are forced to use https
SSL protocol put in place for 90 days"
