#!/bin/bash

if [ "$(whoami)" != 'root' ]; then
        echo 'Run script as ROOT please (sudo)'
        exit
fi

apt-get -y update
apt-get -y upgrade
apt-get -y install openssl
apt-get -y autoremove

echo ''
echo ''
echo 'Stopping Apache2 server..'
apachectl stop
echo 'Apache2 stopped'

sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf

echo ''
echo ''
echo 'Now, we need information to make your SSL certification'
mkdir /etc/apache2/cert/

echo '#!/bin/bash' > /var/www/update-SSL.sh
echo '' >> /var/www/update-SSL.sh
echo 'if [ \"$(whoami)\" != \'root\' ]; then' >> /var/www/update-SSL.sh
echo '	echo \'Run script as ROOT please (sudo)\'' >> /var/www/update-SSL.sh
echo '	exit' >> /var/www/update-SSL.sh
echo 'fi' >> /var/www/update-SSL.sh
echo '' >> /var/www/update-SSL.sh
echo 'openssl req -newkey rsa:2048 -nodes -keyout /etc/apache2/cert/SSL.key -x509 -days 365 -out /etc/apache2/cert/SSL.crt' > /var/www/update-SSL.sh
chmod +x /var/www/update-SSL.sh
/var/www/update-SSL.sh

echo ''
echo ''
read -p 'Server domain (ex: google): ' domain
read -p 'Server tld (ex: com): ' tld

rm -rf /etc/apache2/sites-enabled/*

ip = $(ifconfig | grep 'inet adr:192' | sed -e 's/^.*inet adr:\([0-9\.]*\).*/\1/')

echo '# SSL protocol for local requests' > /etc/apache2/sites-available/SSL-local.conf
echo '<VirtualHost *:443>' >> /etc/apache2/sites-available/SSL-local.conf
echo '	ServerName localhost' >> /etc/apache2/sites-available/SSL-local.conf
echo "	ServerAlias $HOSTNAME $ip 127.0.0.1" >> /etc/apache2/sites-available/SSL-local.conf
echo '	Include /etc/phpmyadmin/apache.conf' >> /etc/apache2/sites-available/SSL-local.conf
echo '	Alias /cloud /var/www/cloud' >> /etc/apache2/sites-available/SSL-local.conf
echo '	SSLEngine On' >> /etc/apache2/sites-available/SSL-local.conf
echo '	SSLCertificateFile /etc/apache2/cert/SSL.crt' >> /etc/apache2/sites-available/SSL-local.conf
echo '	SSLCertificateKeyFile /etc/apache2/cert/SSL.key' >> /etc/apache2/sites-available/SSL-local.conf
echo '</VirtualHost>' >> /etc/apache2/sites-available/SSL-local.conf
ln -s /etc/apache2/sites-available/SSL-local.conf /etc/apache2/sites-enabled/SSL-local.conf

echo '# SSL protocol for cloud requests' > /etc/apache2/sites-available/SSL-cloud.conf
echo '<VirtualHost *:443>' >> /etc/apache2/sites-available/SSL-cloud.conf
echo "	ServerName cloud.$domain.$tld" >> /etc/apache2/sites-available/SSL-cloud.conf
echo '	DocumentRoot /var/www/cloud' >> /etc/apache2/sites-available/SSL-cloud.conf
echo '	SSLEngine On' >> /etc/apache2/sites-available/SSL-cloud.conf
echo '	SSLCertificateFile /etc/apache2/cert/SSL.crt' >> /etc/apache2/sites-available/SSL-cloud.conf
echo '	SSLCertificateKeyFile /etc/apache2/cert/SSL.key' >> /etc/apache2/sites-available/SSL-cloud.conf
echo '</VirtualHost>' >> /etc/apache2/sites-available/SSL-cloud.conf
ln -s /etc/apache2/sites-available/SSL-cloud.conf /etc/apache2/sites-enabled/SSL-cloud.conf

echo '# Force SSL for any (sub)domain' > /etc/apache2/sites-available/SSL.conf
echo '<VirtualHost *:80>' >> /etc/apache2/sites-available/SSL.conf
echo '	RewriteEngine On' >> /etc/apache2/sites-available/SSL.conf
echo '	RewriteCond %{HTTPS} !=on' >> /etc/apache2/sites-available/SSL.conf
echo '	RewriteRule ^/?(.*) https://%{SERVER_NAME}/\$1 [R,L]' >> /etc/apache2/sites-available/SSL.conf
echo '</VirtualHost>' >> /etc/apache2/sites-available/SSL.conf
echo '' >> /etc/apache2/sites-available/SSL.conf
echo '# SSL protocol for others requests' >> /etc/apache2/sites-available/SSL.conf
echo '<VirtualHost *:443>' >> /etc/apache2/sites-available/SSL.conf
echo "	ServerName $domain.$tld" >> /etc/apache2/sites-available/SSL.conf
echo "	ServerAlias *.$domain.$tld" >> /etc/apache2/sites-available/SSL.conf
echo '	DocumentRoot /var/www/html' >> /etc/apache2/sites-available/SSL.conf
echo '	SSLEngine On' >> /etc/apache2/sites-available/SSL.conf
echo '	SSLCertificateFile /etc/apache2/cert/SSL.cert' >> /etc/apache2/sites-available/SSL.conf
echo '	SSLCertificateKeyFile /etc/apache2/cert/SSL.key' >> /etc/apache2/sites-available/SSL.conf
echo '</VirtualHost>' >> /etc/apache2/sites-available/SSL.conf
ln -s /etc/apache2/sites-available/SSL.conf /etc/apache2/sites-enabled/SSL.conf

echo ''
echo ''
echo 'Fixing permissions...'
/var/www/update-permissions.sh
echo 'Permissions fixed'

a2enmod rewrite
a2enmod ssl

apachectl restart
apachectl restart

echo ''
echo ''
echo "Remember, phpmyadmin is only accessible via localhost/phpmyadmin, $HOSTNAME/phpmyadmin, $ip/phpmyadmin or 127.0.0.1/phpmyadmin"
echo "cloud.$domain.$tld redirect to the cloud"
echo 'All requests via internet are forced to use https'
echo 'Don't forget to open/redirect 80/443 ports'
echo 'SSL protocol put in place for 365 days'
echo 'Renew it by executing (with sudo) /var/www/SSL.sh'
