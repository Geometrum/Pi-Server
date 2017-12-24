#!/bin/bash
source incl/include.sh

apt-get -y upgrade
apt-get -y dist-upgrade
apt-get -y install -f
apt-get -y autoremove
$update_file

domain=$server_domain
tld=$server_tld
user=$nextcloud_name
cp skeleton/apache/SSL-user.conf $apache_available_dir/SSL-$user.conf
sed -i "s/\$user/$user/" $apache_available_dir/SSL-$user.conf
sed -i "s/\$domain/$domain/" $apache_available_dir/SSL-$user.conf
sed -i "s/\$tld/$tld/" $apache_available_dir/SSL-$user.conf
sed -i "s/\$www_dir/$www/" $apache_available_dir/SSL-$user.conf
sed -i "s/\$sub/$sub/" $apache_available_dir/SSL-$user.conf
cp $script_dir/skeleton/php-fpm/user.conf /etc/php/7.0/fpm/pool.d/$user.conf
sed -i "s/\$user/$user/g" /etc/php/7.0/fpm/pool.d/$user.conf

wget https://download.nextcloud.com/server/releases/latest.zip
unzip latest.zip
rm latest.zip
mkdir $www_dir/$nextcloud_name
mkdir $www_dir/$nextcloud_name/log
mv nextcloud $nextcloud_dir
ln -s $nextcloud_dir $www_dir/$nextcloud_name/
mv $www_dir/$nextcloud_name/{nextcloud,html}

echo -e "/!\\ Caution ! /!\\
For nextcloud, you have to let your external drive always plugged, you can't change it without changing UUID"

apt-get install -y $drive_fs_driver
$drive_command
uuid=$(sudo blkid $drive_to_mount | sed 's/^.* UUID="\([0-9A-Za-z-]*\)".*$/\1/')

echo -e "# Mount cloud
UUID=$uuid	$nextcloud_dir/data	$drive_fs	$drive_options 0	0" >> /etc/fstab

rm -rf $nextcloud_dir/data && mkdir $nextcloud_dir/data
mount -t $drive_fs -o $drive_cloud_options $drive_to_mount $nextcloud_dir/data

chown -R $web_user:$web_user $nextcloud_dir
chmod -R 700 $nextcloud_dir

echo -e "

Creation of your Nextcloud directory
"
read -sp "Tape a pass for your admin account $cloud_admin: " adminPass
read -sp "Tape a pass to allow Nextcloud to be connected on mysql with $cloud_user user: " pass
echo -e "

Root password (mysql)"
mysql -u root -e "FLUSH PRIVILEGES; CREATE USER \"$cloud_user\"@localhost IDENTIFIED BY \"$pass\"; CREATE DATABASE $nextcloud_name; GRANT ALL PRIVILEGES ON $nextcloud_name.* TO \"$cloud_user\"@localhost;" -p

sudo -u www-data php $nextcloud_dir/occ maintenance:install --database "mysql" --database-name "$nextcloud_name" --database-user "$cloud_user" --database-pass "$pass" --admin-user "$cloud_admin" --admin-pass "$adminPass"
letsencrypt --apache --cert-name $server_domain.$server_tld -d $nextcloud_name.$sub.$server_domain.$server_tld

rm -rf $apache_enabled_dir/*
a2ensite SSL-cloud

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
