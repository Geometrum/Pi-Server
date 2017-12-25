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

AllowUser $ssh_user
AllowGroup $sftp_group" >> $ssh_file

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
sed -i "s/^Alias \/phpmyadmin/#Alias \/phpmyadmin/" /etc/phpmyadmin/apache.conf

echo -e "
# Server name
ServerName $server_name

# Stop sending information
ServerSignature off
ServerTokens Prod" >> $apache_config_file
#Header Always Set Strict-Transport-Security \"includeSubdomains;\"" >> $apache_config_file

echo -e '#!/bin/bash
source incl/include.sh

user="$1"
www=$(echo $www_dir | sed "s/\//\\\//g")
cp $script_dir/skeleton/php-fpm/user.conf /etc/php/7.0/fpm/pool.d/$user.conf
sed -i "s/\$user/$user/g" /etc/php/7.0/fpm/pool.d/$user.conf
sed -i "s/chroot = .*$/chroot = $www\/$user/g" /etc/php/7.0/fpm/pool.d/$user.conf
sed -i "s/php_value[session.save_path] = .*$/php_value[session.save_path] = $www\/$user\/session/g" /etc/php/7.0/fpm/pool.d/$user.conf
sed -i "s/\$domain/$server_domain/g" /etc/php/7.0/fpm/pool.d/$user.conf
sed -i "s/\$tld/$server_tld/g" /etc/php/7.0/fpm/pool.d/$user.conf' > $add_user_file
chmod +x $add_user_file
$add_user_file www
sed -i "s/\chroot = .*$/chroot = $www\/html/g" /etc/php/7.0/fpm/pool.d/$user.conf
sed -i "s/\php_value[session.save_path] = .*$/php_value[session.save_path] = $www\/session/g" /etc/php/7.0/fpm/pool.d/$user.conf
mkdir $www_dir/session

www=$(echo $www_dir | sed "s/\//\\\//g")
domain=$server_domain
tld=$server_tld
cloud_dir=$(echo $nextcloud_dir | sed "s/\//\\\//g")
cp $script_dir/skeleton/apache/local.conf $apache_available_dir/local.conf
sed -i "s/\$server_name/$server_name/" $apache_available_dir/local.conf
sed -i "s/\$local_ip/$local_ip/" $apache_available_dir/local.conf
sed -i "s/\$phpmyadmin_file/\/etc\/phpmyadmin\/apache.conf/" $apache_available_dir/local.conf
sed -i "s/\$nextcloud_name/$nextcloud_name/" $apache_available_dir/local.conf
sed -i "s/\$nextcloud_dir/$cloud_dir/" $apache_available_dir/local.conf

cp $script_dir/skeleton/apache/SSL.conf $apache_available_dir/SSL.conf
sed -i "s/\$domain/$domain/" $apache_available_dir/SSL.conf
sed -i "s/\$tld/$tld/" $apache_available_dir/SSL.conf
sed -i "s/\$www_dir/$www/" $apache_available_dir/SSL.conf

user='phpmyadmin'
cp $script_dir/skeleton/apache/SSL-user.conf $apache_available_dir/SSL-$user.conf
sed -i '/SSLEngine On/i\
\tInclude /etc/phpmyadmin/apache.conf' $apache_available_dir/SSL-phpmyadmin.conf
sed -i "s/\$user/$user/" $apache_available_dir/SSL-$user.conf
sed -i "s/\$domain/$domain/" $apache_available_dir/SSL-$user.conf
sed -i "s/\$tld/$tld/" $apache_available_dir/SSL-$user.conf
sed -i "s/\$www_dir/$www/" $apache_available_dir/SSL-$user.conf
$add_user_file $user

user='www'
cp $script_dir/skeleton/apache/SSL-user.conf $apache_available_dir/SSL-$user.conf
sed -i "s/DocumentRoot \$www_dir\/\$user\/html/DocumentRoot $www\/html/" $apache_available_dir/SSL-$user.conf
sed -i "s/\$user/$user/" $apache_available_dir/SSL-$user.conf
sed -i "s/\$domain/$domain/" $apache_available_dir/SSL-$user.conf
sed -i "s/\$tld/$tld/" $apache_available_dir/SSL-$user.conf
sed -i "s/\$www_dir/$www/" $apache_available_dir/SSL-$user.conf

mkdir $www_dir/phpmyadmin/{,log}
ln -s /usr/share/phpmyadmin $www_dir/phpmyadmin/html

echo -e '
cp $script_dir/skeleton/apache/SSL-user.conf $apache_available_dir/SSL-$user.conf
sed -i "s/\$user/$user/" $apache_available_dir/SSL-$user.conf
sed -i "s/\$domain/$domain/" $apache_available_dir/SSL-$user.conf
sed -i "s/\$tld/$tld/" $apache_available_dir/SSL-$user.conf
sed -i "s/\$www_dir/$www/" $apache_available_dir/SSL-$user.conf

mkdir $www_dir/$user/
cp -rf $script_dir/skeleton/user/* $www_dir/$user/
ln -s /var/log/php-fpm/$user/ $www_dir/$user/log

sed -i "s/server_subdomains=(\(.*\))/server_subdomains=(\1 $user)/ $script_dir/incl/config"

a2ensite SSL-$user

systemctl daemon-reload
/etc/init.d/php7.0-fpm reload
/etc/init.d/apache2 reload

certbot --apache --expand -d $server_domain.$server_tld -d $user.$server_domain.$server_tld' >> $add_user_file

rm -rf $apache_enabled_dir/*
a2ensite local SSL SSL-phpmyadmin

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

echo -e "

Installation complited
Your website contains two files: one to test Apache2, the second to prompt PHP infos
Go to localhost/phpmyadmin, $server_name/phpmyadmin, $local_ip/phpmyadmin, 127.0.0.1/phpmyadmin to access to PhpMyAdmin
All requests via internet are forced to use https
SSL protocol put in place for 90 days, you can renew your
Can now create new sub website/user via add_user file"
