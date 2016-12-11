#!/bin/bash
source incl/include.sh

apt-get -y update
apt-get -y upgrade
apt-get -y install openssl
apt-get -y autoremove

/etc/init.d/apache2 stop

sed -i 's/AllowOverride None/AllowOverride All/' $apache_config_file

echo -e '

Now, we need information to make your SSL certification'
mkdir $apache_dir/SSL/

echo -e "#!/bin/bash
source incl/include.sh

openssl req -newkey rsa:2048 -nodes -keyout \$apache_dir/SSL/SSL.key -x509 -days 365 -out \$apache_dir/SSL/SSL.crt" > $update_SSL_file
chmod +x $update_SSL_file
$update_SSL_file

echo -e '
'
read -p 'Server domain (ex: google): ' domain
read -p 'Server tld (ex: com): ' tld

rm -rf $apache_enabled_dir/*

local_ip=$(ifconfig | grep 'inet adr:192' | sed -e 's/^.*inet adr:\([0-9\.]*\).*/\1/')
echo -e "# SSL protocol for local requests
<VirtualHost *:443>
	ServerName localhost
	ServerAlias $server_name $local_ip 127.0.0.1
	Include $phpmyadmin_file
	Alias /$nextcloud_name $nextcloud_dir
	SSLEngine On
	SSLCertificateFile $apache_dir/SSL/SSL.crt
	SSLCertificateKeyFile $apache_dir/SSL/SSL.key
</VirtualHost>" > $apache_available_dir/SSL-local.conf
ln -s $apache_available_dir/SSL-local.conf $apache_enabled_dir/SSL-local.conf

echo -e "# SSL protocol for cloud requests
<VirtualHost *:443>
	ServerName cloud.$domain.$tld
	DocumentRoot $nextcloud_dir
	SSLEngine On
	SSLCertificateFile $apache_dir/SSL/SSL.crt
	SSLCertificateKeyFile $apache_dir/SSL/SSL.key
</VirtualHost>" > $apache_available_dir/SSL-cloud.conf
ln -s $apache_available_dir/SSL-cloud.conf $apache_enabled_dir/SSL-cloud.conf

echo -e "# SSL protocol for phpmyadmin requests
<VirtualHost *:443>
	ServerName phpmyadmin.$domain.$tld
	DocumentRoot /usr/share/phpmyadmin
	SSLEngine On
	SSLCertificateFile $apache_dir/SSL/SSL.crt
	SSLCertificateKeyFile $apache_dir/SSL/SSL.key
</VirtualHost>" > $apache_available_dir/SSL-phpmyadmin.conf
ln -s $apache_available_dir/SSL-phpmyadmin.conf $apache_enabled_dir/SSL-phpmyadmin.conf

echo -e "# Force SSL for any (sub)domain
<VirtualHost *:80>
	RewriteEngine On
	RewriteCond %{HTTPS} !=on
	RewriteRule ^/?(.*) https://%{SERVER_NAME}/\$1 [R,L]
</VirtualHost>

# SSL protocol for others requests
<VirtualHost *:443>
	ServerName $domain.$tld
	ServerAlias *.$domain.$tld
	DocumentRoot $web_dir
	Include $phpmyadmin_file
	Alias /$nextcloud_name $nextcloud_dir
	SSLEngine On
	SSLCertificateFile $apache_dir/SSL/SSL.crt
	SSLCertificateKeyFile $apache_dir/SSL/SSL.key
</VirtualHost>" > $apache_available_dir/SSL.conf
ln -s $apache_available_dir/SSL.conf $apache_enabled_dir/SSL.conf

echo ''
echo ''
$update_permissions_file

a2enmod rewrite
a2enmod ssl

systemctl daemon-reload && /etc/init.d/apache2 restart

echo -e "

Remember, phpmyadmin is only accessible via localhost/phpmyadmin, $HOSTNAME/phpmyadmin, $local_ip/phpmyadmin or 127.0.0.1/phpmyadmin
cloud.$domain.$tld redirect to the cloud
All requests via internet are forced to use https
Do not forget to open/redirect 80/443 ports
SSL protocol put in place for 365 days
Renew it by executing (with sudo) $update_SSL_file"
