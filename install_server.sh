#!/bin/bash
source incl/include.sh

groupadd $sftp_group
useradd -g $sftp_group $sftp_user
echo -e "
Now, we need a password for $sftp_user user:"
passwd $sftp_user

echo -e "

# Allow input HTTP(S) requests
iptables -t filter -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -t filter -A INPUT -p tcp --dport 443 -j ACCEPT" >> /etc/init.d/firewall
/etc/init.d/firewall

echo -e "
# Directory for users
Match User $sftp_user
	ChrootDirectory $www_dir/
	ForceCommand internal-sftp

Match Group $sftp_group
	ChrootDirectory $www_dir/%u/
	ForceCommand internal-sftp

AllowUsers $ssh_user
AllowGroups $sftp_group" >> $ssh_file
systemctl reload ssh

apt-get -y upgrade
apt-get -y dist-upgrade
apt-get -y install -f
apt-get -y autoremove

apt-get -y install apache2 libapache2-mod-fcgid python-certbot-apache
apt-get -y install mysql-server mysql-client
apt-get -y install php php-fpm php-cli php-mysql php-curl php-bz2 php-gd php-zip php-mcrypt php-json php-memcached php-xml php-opcache
apt-get -y install phpmyadmin
apt-get -y install -f
apt-get -y autoremove

systemctl daemon-reload && /etc/init.d/apache2 restart

mysql -e "USE mysql; UPDATE user SET plugin='mysql_native_password' WHERE User='root'; FLUSH PRIVILEGES;"
mysql_secure_installation

/etc/init.d/apache2 stop

apt-get -y upgrade
apt-get -y dist-upgrade
apt-get -y install -f
apt-get -y autoremove

a2enmod proxy_fcgi proxy_http actions rewrite ssl

mv $web_dir/{index.html,apache.html}
echo '<?php phpinfo(); ?>' > $web_dir/php.php

mv /etc/php/7.0/fpm/pool.d/www.conf $script_dir/skeleton/php-fpm/www.conf.bckp
mkdir /var/log/php-fpm/

echo -e "
# Server name
ServerName $server_name

# Stop sending information
ServerSignature off
ServerTokens Prod" >> $apache_config_file
#Header Always Set Strict-Transport-Security \"includeSubdomains;\"" >> $apache_config_file

echo -e "
opcache.enable=1
opcache.enable_cli=1
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=10000
opcache.memory_consumption=128
opcache.save_comments=1
opcache.revalidate_freq=1" >> /etc/php/7.0/fpm/php.ini

echo -e '#!/bin/bash
source incl/include.sh

user="$1"

mkdir /var/log/php-fpm/$user

cp $script_dir/skeleton/php-fpm/user.conf /etc/php/7.0/fpm/pool.d/$user.conf
sed -i "s/\$user/$user/g" /etc/php/7.0/fpm/pool.d/$user.conf
sed -i "s~\$www_dir~$www_dir~g" /etc/php/7.0/fpm/pool.d/$user.conf
sed -i "s/\$domain/$server_domain/g" /etc/php/7.0/fpm/pool.d/$user.conf
sed -i "s/\$tld/$server_tld/g" /etc/php/7.0/fpm/pool.d/$user.conf' > $add_user_file
chown $ssh_user:$ssh_user $add_user_file
chmod +x $add_user_file
$add_user_file www
sed -i "s~user = .*$~user = www-data~g" /etc/php/7.0/fpm/pool.d/www.conf
sed -i "s~group = .*$~group = www-data~g" /etc/php/7.0/fpm/pool.d/www.conf
sed -i "s~listen.owner = .*$~listen.owner = www-data~g" /etc/php/7.0/fpm/pool.d/www.conf
sed -i "s~chroot = .*$~chroot = $www_dir/html~g" /etc/php/7.0/fpm/pool.d/www.conf
sed -i "s~chroot = .*$~chroot = $www_dir/html~g" /etc/php/7.0/fpm/pool.d/www.conf
sed -i "s~php_value\[session.save_path\] = .*$~php_value\[session.save_path\] = $www_dir/session~g" /etc/php/7.0/fpm/pool.d/www.conf
mkdir $www_dir/session

domain=$server_domain
tld=$server_tld
cp $script_dir/skeleton/apache/local.conf $apache_available_dir/local.conf
sed -i "s/\$server_name/$server_name/g" $apache_available_dir/local.conf
sed -i "s/\$local_ip/$local_ip/g" $apache_available_dir/local.conf
sed -i "s/\$phpmyadmin_file/\/etc\/phpmyadmin\/apache.conf/g" $apache_available_dir/local.conf
sed -i "s/\$nextcloud_name/$nextcloud_name/g" $apache_available_dir/local.conf
sed -i "s~\$nextcloud_dir~$nextcloud_dir~g" $apache_available_dir/local.conf

cp $script_dir/skeleton/apache/SSL-www.conf $apache_available_dir/SSL-www.conf
sed -i "s/\$domain/$domain/g" $apache_available_dir/SSL-www.conf
sed -i "s/\$tld/$tld/g" $apache_available_dir/SSL-www.conf
sed -i "s~\$www_dir~$www_dir~g" $apache_available_dir/SSL-www.conf

user='phpmyadmin'
cp $script_dir/skeleton/apache/SSL-user.conf $apache_available_dir/SSL-$user.conf
sed -i '/SSLEngine On/i\
\tInclude /etc/phpmyadmin/apache.conf' $apache_available_dir/SSL-phpmyadmin.conf
sed -i "s/\$user/$user/g" $apache_available_dir/SSL-$user.conf
sed -i "s/\$domain/$domain/g" $apache_available_dir/SSL-$user.conf
sed -i "s/\$tld/$tld/g" $apache_available_dir/SSL-$user.conf
sed -i "s~\$www_dir~$www_dir~g" $apache_available_dir/SSL-$user.conf
$add_user_file $user
sed -i "s~user = .*$~user = www-data~g" /etc/php/7.0/fpm/pool.d/$user.conf
sed -i "s~group = .*$~group = www-data~g" /etc/php/7.0/fpm/pool.d/$user.conf
sed -i "s~listen.owner = .*$~listen.owner = www-data~g" /etc/php/7.0/fpm/pool.d/$user.conf

mkdir $www_dir/phpmyadmin/{,log}
ln -s /usr/share/phpmyadmin $www_dir/phpmyadmin/html

echo -e '
useradd -U $user -d $www_dir/$user/

cp $script_dir/skeleton/apache/SSL-user.conf $apache_available_dir/SSL-$user.conf
sed -i "s/\$user/$user/g" $apache_available_dir/SSL-$user.conf
sed -i "s/\$domain/$server_domain/g" $apache_available_dir/SSL-$user.conf
sed -i "s/\$tld/$server_tld/g" $apache_available_dir/SSL-$user.conf
sed -i "s~\$www_dir~$www_dir~g" $apache_available_dir/SSL-$user.conf

mkdir $www_dir/$user/
cp -rf $script_dir/skeleton/user/* $www_dir/$user/
mkdir /var/log/php-fpm/$user
touch /var/log/php-fpm/error.log
chown $www-data:$www-data -R /var/log/php-fpm/$user
chown $user:$www-data /var/log/php-fpm/$user/error.log
ln -s /var/log/php-fpm/$user/ $www_dir/$user/log

sed -i "s/server_subdomains=(\(.*\))/server_subdomains=(\1 $user)/" $script_dir/incl/config

a2ensite SSL-$user

systemctl daemon-reload
/etc/init.d/php7.0-fpm reload
/etc/init.d/apache2 reload

chown $user:$user -R $www_dir/$user

certbot --apache --expand -d $server_domain.$server_tld -d $user.$server_domain.$server_tld' >> $add_user_file

rm -rf $apache_enabled_dir/*
a2ensite local SSL-www SSL-phpmyadmin local

systemctl daemon-reload
/etc/init.d/php7.0-fpm restart
/etc/init.d/apache2 restart

letsencrypt_options="--apache -d $server_domain.$server_tld"
for sub in "${server_subdomains[@]}"; do
	letsencrypt_options="$letsencrypt_options -d $sub.$server_domain.$server_tld"
done
certbot $letsencrypt_options

systemctl daemon-reload
/etc/init.d/apache2 restart
/etc/init.d/php7.0-fpm restart

chown $web_user:$web_user -R $www_dir

echo -e "

Installation complited
Your website contains two files: one to test Apache2, the second to prompt PHP infos
Go to localhost/phpmyadmin, $server_name/phpmyadmin, $local_ip/phpmyadmin, 127.0.0.1/phpmyadmin to access to PhpMyAdmin
All requests via internet are forced to use https
SSL protocol put in place for 90 days, you can renew your
Can now create new sub website/user via add_user file"
