#!/bin/bash

if [ "$(whoami)" != 'root' ]; then
        echo 'Run script as ROOT please (sudo)'
        exit
fi

echo '#!/bin/bash' > /var/www/update.sh
echo '' >> /var/www/update.sh
echo 'if [ "$(whoami)" != "root" ]; then' >> /var/www/update.sh
echo '  echo "Run script as ROOT please (sudo)"' >> /var/www/update.sh
echo '  exit' >> /var/www/update.sh
echo 'fi' >> /var/www/update.sh
echo '' >> /var/www/update.sh
echo 'apt-get -y install apache2 php5 php5-curl php5-mysql mysql-client mysql-server' >> /var/www/update.sh
echo 'aptitude -y install phpmyadmin' >> /var/www/update.sh
echo 'apt-get -y install -f' >> /var/www/update.sh
echo 'apt-get -y autoremove' >> /var/www/update.sh
echo '' >> /var/www/update.sh
echo 'apachectl restart' >> /var/www/update.sh
echo 'apachectl restart' >> /var/www/update.sh
chmod +x /var/www/update.sh
/var/www/update.sh

mv /var/www/html/{index.html,apache.html}
echo '<?php phpinfo(); ?>' > /var/www/html/php.php

chown -R pi:www-data /var/www/

rm -rf /etc/apache2/sites-enabled/*

echo '' >> /etc/apache2/apache2.conf
echo '# Server name to avoid a useless warning' >> /etc/apache2/apache2.conf
echo "ServerName $HOSTNAME" >> /etc/apache2/apache2.conf

apachectl restart

wget https://download.nextcloud.com/server/releases/nextcloud-10.0.1.tar.bz2
tar -xvf nextcloud*
mv nextcloud /var/www/cloud
rm -rf nextcloud*

ip=$(ifconfig | grep 'inet adr:192' | sed -e 's/^.*inet adr:\([0-9\.]*\).*/\1/')
echo '# Include phpmyadmin with /phpmyadmin and cloud with /cloud' > /etc/apache2/sites-available/local.conf
echo '<VirtualHost *:80>' >> /etc/apache2/sites-available/local.conf
echo '	ServerName localhost' >> /etc/apache2/sites-available/local.conf
echo "	ServerAlias $HOSTNAME $ip 127.0.0.1" >> /etc/apache2/sites-available/local.conf
echo '	Include /etc/phpmyadmin/apache.conf' >> /etc/apache2/sites-available/local.conf
echo '	Alias /cloud /var/www/cloud' >> /etc/apache2/sites-available/local.conf
echo '</VirtualHost>' >> /etc/apache2/sites-available/local.conf
ln -s /etc/apache2/sites-available/local.conf /etc/apache2/sites-enabled/local.conf

apachectl restart

echo ''
echo ''
read -sp 'Tape a pass to allow Nextcloud to be connected on mysql with www-data user: ' pass
echo 'Tape your pass to be connected on mysql as root'
mysql -u root -e "FLUSH PRIVILEGES;CREATE DATABASE cloud;GRANT ALL PRIVILEGES ON cloud.* TO \"www-data\"@localhost IDENTIFIED BY \"$pass\";" -p

apt-get -y install ntfs-3g

echo '/dev/sda1	/var/www/cloud/data	ntfs-3g	defaults,permissions,nofail	0	0' >> /etc/fstab
rm -rf /var/www/cloud/data/
mkdir /var/www/cloud/data
mount -t ntfs-3g -o defaults,permissions,nofail /dev/sda1 /var/www/cloud/data

echo '#!/bin/bash' > /var/www/update-permissions.sh
echo '' >> /var/www/update-permissions.sh
echo 'if [ "$(whoami)" != "root" ]; then' >> /var/www/update-permissions.sh
echo '	echo "Run script as ROOT please (sudo)"' >> /var/www/update-permissions.sh
echo '	exit' >> /var/www/update-permissions.sh
echo 'fi' >> /var/www/update-permissions.sh
echo '' >> /var/www/update-permissions.sh
echo 'chown -R pi:www-data /var/www' >> /var/www/update-permissions.sh
echo 'chmod -R 770 /var/www' >> /var/www/update-permissions.sh
chmod +x /var/www/update-permissions.sh
/var/www/update-permissions.sh

echo ''
echo ''
echo 'Installation ended'
echo 'If they are some permission problems, execute /var/www/update_permissions.sh (with sudo)'
echo 'Your website contains two files: one to test Apache2, the second to prompt PHP infos'
echo "Go to localhost/phpmyadmin, $HOSTNAME/phpmyadmin, $ip/phpmyadmin, 127.0.0.1/phpmyadmin to access to PhpMyAdmin"
echo 'Now, set Nextcloud parameters going to localhost/cloud'
