#!/bin/bash
source incl/include.sh

mkdir $script_dir
cp -rf incl $script_dir/

echo -e "#!/bin/bash
source incl/include.sh

apt-get -y install apache2
apt-get -y install mysql-client mysql-server
apt-get -y install php5 php5-curl php5-mysql
aptitude -y install phpmyadmin
apt-get -y install -f
apt-get -y autoremove

systemctl daemon-reload && /etc/init.d/apache2 restart" > $update_file
chmod +x $update_file
$update_file

mv $web_dir/{index.html,apache.html}
echo '<?php phpinfo(); ?>' > $web_dir/php.php

chown -R $user:$web_user $www_dir

rm -rf $apache_enabled_dir/*

echo -e "
# Server name
ServerName $server_name" >> $apache_config_file

/etc/init.d/apache2 stop

wget -O /tmp/install_nextcloud.php https://download.nextcloud.com/server/installer/setup-nextcloud.php
echo -e "

Creation of your Nextcloud directory"
php -r '$_GET["step"]="2"; $_GET["directory"]="nextcloud"; require_once("/tmp/install_nextcloud.php");' > /dev/null
mv nextcloud $nextcloud_dir

local_ip=$(ifconfig | grep 'inet adr:192' | sed -e 's/^.*inet adr:\([0-9\.]*\).*/\1/')
echo -e "# Include phpmyadmin with /phpmyadmin and nextcloud with /$nextcloud_name
<VirtualHost *:80>
	ServerName localhost
	ServerAlias $server_name $local_ip 127.0.0.1
	Include $phpmyadmin_file
	Alias /$nextcloud_name $nextcloud_dir
</VirtualHost>" > $apache_available_dir/local.conf
ln -s $apache_available_dir/local.conf $apache_enabled_dir/local.conf

systemctl daemon-reload && /etc/init.d/apache2 restart

echo -e "
"
read -sp "Tape a pass to allow Nextcloud to be connected on mysql with $web_user user: " pass
echo -e '
Tape your pass to be connected on mysql as root'
mysql -u root -e "FLUSH PRIVILEGES; CREATE DATABASE $nextcloud_name; GRANT ALL PRIVILEGES ON $nextcloud_name.* TO \"$web_user\"@localhost IDENTIFIED BY \"$pass\";" -p

apt-get -y install ntfs-3g

echo -e "# Mount data
/dev/sda1	$nextcloud_dir/data	ntfs-3g	defaults,permissions,nofail	0	0" >> /etc/fstab
rm -rf $nextcloud_dir/data
mkdir $nextcloud_dir/data
mount -t ntfs-3g -o defaults,permissions,nofail /dev/sda1 $nextcloud_dir/data

chown -R $user:$web_user $nextcloud_dir
chmod -R 770 $nextcloud_dir

echo -e "#!/bin/bash
source incl/include.sh

echo 'Fixing permissions...'

chown root:\$user \$www_dir
chmod 750 \$www_dir

chown -R \$user:\$web_user \$web_dir
chmod -R 770 \$web_dir

chown -R root:\$user \$script_dir
chmod -R 770 \$script_dir

echo 'Permissions fixed'" > $update_permissions_file
chmod +x $update_permissions_file
$update_permissions_file

systemctl daemon-reload && /etc/init.d/apache2 restart

echo -e "

Installation ended
If they are some permission problems, execute $update_permissions_file (with sudo)
Your website contains two files: one to test Apache2, the second to prompt PHP infos
Go to localhost/phpmyadmin, $server_name/phpmyadmin, $local_ip/phpmyadmin, 127.0.0.1/phpmyadmin to access to PhpMyAdmin
Now, set Nextcloud parameters going to localhost/$nextcloud_name"
