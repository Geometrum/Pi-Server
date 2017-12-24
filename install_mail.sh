#!/bin/bash
source incl/include.sh

apt-get -y update
$update_file
apt-get -y install roundcube postfix dovecot-pop3d dovecot-imapd opendkim opendkim-tools

# ????
chmod o+rwx $mail_dir

echo -e "
# Use dovecot to manage mails
mailbox_command = /usr/lib/dovecot/dovecot-lda -f \"\$SENDER\" -a \"\$RECIPIENT\"" >> /etc/postfix/main.cf
echo -e "
# Mail location
mail_location = maildir:/var/mail/%n:UTF-8" >> /etc/dovecot/dovecot.conf

ln -s /usr/share/roundcube $www_dir/mail

user='mail'
eval echo `cat skeleton/apache/SSL-user.conf` > $apache_available_dir/SSL-mail.conf
sed -i '/SSLEngine On/i\
\tInclude /etc/roundcube/apache.conf' $apache_available_dir/SSL-mail.conf

#letsencrypt_options="--apache -d $server_domain.$server_tld"
#for sub in "${server_subdomains[@]}"; do
#	letsencrypt_options="$letsencrypt_options -d $sub.$server_domain.$server_tld"
#done
#letsencrypt $letsencrypt_options

a2ensite SSL-mail

systemctl daemon-reload
/etc/init.d/apache2 restart
/etc/init.d/php7.0-fpm restart
/etc/init.d/postfix restart
/etc/init.d/dovecot restart

# Tout est à faire

echo -e "

Installation complited
Your website contains two files: one to test Apache2, the second to prompt PHP infos
Go to localhost/phpmyadmin, $server_name/phpmyadmin, $local_ip/phpmyadmin, 127.0.0.1/phpmyadmin to access to PhpMyAdmin
cloud.$server_domain.$server_tld redirect to the cloud but before, you have to set Nextcloud parameters going to localhost/$nextcloud_name
All requests via internet are forced to use https
SSL protocol put in place for 90 days"
