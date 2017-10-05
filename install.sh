#!/bin/bash
source incl/include.sh

apt-get -y upgrade
apt-get -y dist-upgrade
apt-get -y install -f
apt-get -y autoremove

systemctl stop portsentry

echo -e "#!/bin/bash
source incl/include.sh

apt-get -y install apache2 libapache2-mod-fcgid python-certbot-apache
apt-get -y install mysql-server mysql-client
apt-get -y install php7.0 php7.0-fpm php7.0-cli php7.0-mysql php7.0-curl php7.0-bz2 php7.0-gd php7.0-zip php7.0-mcrypt php7.0-json php7.0-memcached php7.0-xml php7.0-opcache
apt-get -y install phpmyadmin gitlab-ce
apt-get -y install roundcube postfix dovecot-pop3d dovecot-imapd opendkim opendkim-tools
apt-get -y install -f
apt-get -y autoremove

systemctl daemon-reload && /etc/init.d/apache2 restart" > $update_file
chmod +x $update_file
$update_file

/etc/init.d/apache2 stop

apt-get -y upgrade
apt-get -y dist-upgrade
apt-get -y install -f
apt-get -y autoremove

a2enmod proxy_fcgi proxy_http actions rewrite ssl
a2enconf php7.0-fpm

mv $web_dir/{index.html,apache.html}
echo '<?php phpinfo(); ?>' > $web_dir/php.php

chown root:$web_user $web_dir
chmod o+rwx $mail_dir

echo -e "
# Use dovecot to manage mails
mailbox_command = /usr/lib/dovecot/dovecot-lda -f \"\$SENDER\" -a \"\$RECIPIENT\"" >> /etc/postfix/main.cf
echo -e "
# Mail location
mail_location = maildir:/var/mail/%n:UTF-8" >> /etc/dovecot/dovecot.conf

www_dir=$(echo $www_dir | sed 's/\//\\\//g')
cp /etc/php/7.0/fpm/pool.d/www.conf $script_dir/skeleton/php-fpm/user.conf
sed -i 's/^.{,2}listen =.*$/listen = \/run\/php\/www.sock/' /etc/php/7.0/fpm/pool.d/www.conf
sed -i 's/^.{,2}listen\.allowed_clients =/listen\.allowed_clients =/' /etc/php/7.0/fpm/pool.d/www.conf
sed -i 's/^.{,2}process\.priority =.*$/process\.priority = -19/' /etc/php/7.0/fpm/pool.d/www.conf
sed -i 's/^.{,2}pm\.max_children =.*$/pm\.max_children = 20/' /etc/php/7.0/fpm/pool.d/www.conf
sed -i 's/^.{,2}pm\.start_servers =.*$/pm\.start_servers = 5/' /etc/php/7.0/fpm/pool.d/www.conf
sed -i 's/^.{,2}pm\.min_spare_servers =.*$/pm\.min_spare_servers = 5/' /etc/php/7.0/fpm/pool.d/www.conf
sed -i 's/^.{,2}pm\.max_spare_servers =.*$/pm\.max_spare_servers = 10/' /etc/php/7.0/fpm/pool.d/www.conf
sed -i "s/^.{,2}access\.log =.*$/access\.log = $www_dir\/log\/access.log/" /etc/php/7.0/fpm/pool.d/www.conf
sed -i 's/^.{,2}access\.format = /access\.format = /' /etc/php/7.0/fpm/pool.d/www.conf
sed -i "s/^.{,2}slowlog =.*$/slowlog = $www_dir\/log\/slow.log/" /etc/php/7.0/fpm/pool.d/www.conf
sed -i 's/^.{,2}request_slowlog_timeout =.*$/request_slowlog_timeout = 10/' /etc/php/7.0/fpm/pool.d/www.conf
sed -i 's/^.{,2}request_terminate_timeout =.*$/request_terminate_timeout = 60/' /etc/php/7.0/fpm/pool.d/www.conf
sed -i "s/^.{,2}php_admin_value\[sendmail\.path\] =.*$/php_admin_value\[sendmail\.path\] = \/usr\/bin\/sendmail -t -i -f $ssh_user@$domain.$tld/" /etc/php/7.0/fpm/pool.d/www.conf
sed -i "s/^.{,2}php_admin_value\[error_log\] =.*$/php_admin_value\[error_log\] = $www_dir\/log\/error.log/" /etc/php/7.0/fpm/pool.d/www.conf

sed -i "s/^Alias \/phpmyadmin/#Alias \/phpmyadmin/" /etc/phpmyadmin/apache.conf

echo -e "
# Server name
ServerName $server_name

# Stop sending information
ServerSignature off
ServerTokens Prod
Header Always Set Strict-Transport-Security \"includeSubdomains;\"" >> $apache_config_file

ln -s /opt/gitlab/embedded/service/gitlab-rails/public $www_dir/gitlab
ln -s /usr/share/phpmyadmin $www_dir/phpmyadmin
ln -s /usr/share/roundcube $www_dir/mail

sub='www'
eval echo `cat skeleton/apache/local.conf` > $apache_available_dir/local.conf
eval echo `cat skeleton/apache/error.conf` > $apache_available_dir/error.conf
eval echo `cat skeleton/apache/SSL.conf` > $apache_available_dir/SSL.conf
eval echo `cat skeleton/apache/SSL-gitlab.conf` > $apache_available_dir/SSL-gitlab.conf

user='phpmyadmin'
eval echo `cat skeleton/apache/SSL-user.conf` > $apache_available_dir/SSL-phpmyadmin.conf
sed -i '/SSLEngine On/i\
\tInclude /etc/phpmyadmin/apache.conf' $apache_available_dir/SSL-phpmyadmin.conf

user='mail'
eval echo `cat skeleton/apache/SSL-user.conf` > $apache_available_dir/SSL-mail.conf
sed -i '/SSLEngine On/i\
\tInclude /etc/roundcube/apache.conf' $apache_available_dir/SSL-mail.conf

user=$nextcloud_name
eval echo `cat skeleton/apache/SSL-user.conf` > $apache_available_dir/SSL-$nextcloud_name.conf

user='back'
eval echo `cat skeleton/apache/SSL-user.conf` > $apache_available_dir/SSL-back.conf

user='incl'
eval echo `cat skeleton/apache/SSL-user.conf` > $apache_available_dir/SSL-incl.conf

user='www'
eval echo `cat skeleton/apache/SSL-user.conf` > $apache_available_dir/SSL-www.conf

wget -O install_nextcloud.php https://download.nextcloud.com/server/installer/setup-nextcloud.php
echo -e "

Creation of your Nextcloud directory"
php -r '$_GET["step"]="2"; $_GET["directory"]="nextcloud"; require_once("install_nextcloud.php");' > /dev/null
mv nextcloud $nextcloud_dir
ln -s $nextcloud_dir $www_dir/$nextcloud_name
rm -rf *nextcloud*

echo -e "
"
read -sp "Tape a pass to allow Nextcloud to be connected on mysql with $web_user user: " pass
echo -e '
Tape your pass to be connected on mysql as root'
mysql -u root -e "FLUSH PRIVILEGES; CREATE DATABASE $nextcloud_name; GRANT ALL PRIVILEGES ON $nextcloud_name.* TO \"$web_user\"@localhost IDENTIFIED BY \"$pass\";" -p

echo -e "/!\\ Caution ! /!\\
For nextcloud, you have to let your external drive always plugged, you can't change it without changing UUID"

apt-get install -y $drive_fs_driver
uuid=$(sudo blkid $drive_to_mount | sed 's/^.* UUID="\([0-9A-Za-z-]*\)".*$/\1/')

echo -e "# Mount cloud
UUID=$uuid	$nextcloud_dir/data	$drive_fs	$drive_options 0	0
# Mount gitlab
UUID=$uuid	/var/opt/gitlab/git-data	$drive_fs	$drive_options 0	0" >> /etc/fstab

rm -rf $nextcloud_dir/data && mkdir $nextcloud_dir/data
mount -t $drive_fs -o $drive_cloud_options $drive_to_mount $nextcloud_dir/data

rm -rf /var/opt/gitlab/git-data && mkdir /var/opt/gitlab/git-data
mount -t $drive_fs -o $drive_gitlab_options $drive_to_mount /var/opt/gitlab/git-data

cp -rf skeleton/user/* $www_dir/

chown -R $web_user:$web_user $nextcloud_dir
chmod -R 700 $nextcloud_dir

sed -i "s/^external_url.*$/external_url 'https:\/\/gitlab.$domain.$tld'/" /etc/gitlab/gitlab.rb
echo -e "# Stop nginx
nginx['enable'] = false
nginx['listen_https'] = false" >> /etc/gitlab/gitlab.rb
gitlab-ctl reconfigure

letsencrypt_options="--apache -d $server_domain.$server_tld"
for sub in "${server_subdomains[@]}"; do
	letsencrypt_options="$letsencrypt_options -d $sub.$server_domain.$server_tld"
done
letsencrypt $letsencrypt_options

#a2dismod php7.0
rm -rf $apache_enabled_dir/*
a2ensite error local SSL SSL-cloud SSL-phpmyadmin SSL-incl SSL-back SSL-gitlab

systemctl daemon-reload
gitlab-ctl restart
/etc/init.d/apache2 restart
/etc/init.d/php7.0-fpm restart
/etc/init.d/postfix restart
/etc/init.d/dovecot restart
/etc/init.d/portsentry restart

echo -e "

Installation complited
Your website contains two files: one to test Apache2, the second to prompt PHP infos
Go to localhost/phpmyadmin, $server_name/phpmyadmin, $local_ip/phpmyadmin, 127.0.0.1/phpmyadmin to access to PhpMyAdmin
cloud.$server_domain.$server_tld redirect to the cloud but before, you have to set Nextcloud parameters going to localhost/$nextcloud_name
All requests via internet are forced to use https
SSL protocol put in place for 90 days"
