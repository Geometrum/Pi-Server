#!/bin/bash

if [ "$(whoami)" != 'root' ]; then
        echo 'Run script as ROOT please (sudo)'
        exit
fi

sshd_file='/etc/ssh/sshd_config'
add_user_file='/var/www/add-sftp.sh'
del_user_file='/var/www/del-sftp.sh'
firewall_file='/var/www/update-firewall.sh'
apache_file='/etc/apache2/apache2.conf'

permissions_file='/var/www/update-permissions.sh'

echo ''
echo ''
read -p 'Which port will be used for SSH requests (22): ' SSH

sed -i "s/^Port 22/Port $SSH/" $sshd_file
sed -i "s/^PermitRootLogin without-password/PermitRootLogin no/" $sshd_file
sed -i "s/^Subsystem sftp/#Subsystem sftp/" $sshd_file
sed -i "s/^UsePAM yes/#UsePAM yes/" $sshd_file
echo '' >> $sshd_file
echo '# Directory for sftp users' >> $sshd_file
echo 'SubSystem sftp internal-sftp' >> $sshd_file
echo 'Match Group www-data' >> $sshd_file
echo '	ChrootDirectory %h' >> $sshd_file
echo '	ForceCommand internal-sftp' >> $sshd_file
echo 'AllowGroups www-data' >> $sshd_file

echo ''
echo ''
echo 'Creation of your sftp account (sftp)'
useradd -g www-data sftp -s /bin/false
passwd sftp
mkdir /home/sftp/{,html}
mount --bind /var/www/html /home/sftp/html
echo '# Mount server points' >> /etc/fstab
echo '/var/www/html	/home/sftp/html	none	defaults,blind' >> /etc/fstab
chown -R root:www-data /home/sftp
chmod 750 /home/sftp
chmod 770 /home/sftp/*

echo '#!/bin/bash' > $add_user_file
echo '' >> $add_user_file
echo 'if [ "$(whoami)" != "root" ]; then' >> $add_user_file
echo '  echo "Run script as ROOT please (sudo)"' >> $add_user_file
echo '  exit' >> $add_user_file
echo 'fi' >> $add_user_file
echo '' >> $add_user_file
echo 'read -p "New user to create with directory in /var/www/html: " user' >> $add_user_file
echo '' >> $add_user_file
echo 'useradd -g www-data $user -s /bin/false' >> $add_user_file
echo 'passwd $user' >> $add_user_file
echo '' >> $add_user_file
echo 'mkdir /var/www/html/$user /home/$user/{,html}' >> $add_user_file
echo 'mount --bind /var/www/html/$user /home/$user/html' >> $add_user_file
echo 'echo "/var/www/html/$user	/home/$user/html	none	defaults,bind" >> /etc/fstab' >> $add_user_file
echo '' >> $add_user_file
echo 'read -sp "Password for $user to connect to phpmyadmin: " pass' >> $add_user_file
echo 'echo "Tape your pass to be connected on mysql as root"' >> $add_user_file
echo 'mysql -u root -e "FLUSH PRIVILEGES;CREATE DATABASE $user;GRANT ALL PRIVILEGES ON $user.* TO \"$user\"@\"%\" IDENTIFIED BY \"$pass\";" -p' >> $add_user_file
echo '' >> $add_user_file
echo 'chown -R root:www-data /home/$user' >> $add_user_file
echo 'chmod 750 /home/$user' >> $add_user_file
echo 'chmod 770 /home/$user/*' >> $add_user_file
echo "echo \"<?php echo 'Welcome to your directory, \$user'; ?>\" > /var/www/html/\$user/index.php" >> $add_user_file
echo $permissions_file >> $add_user_file
echo '' >> $add_user_file
echo 'echo ""' >> $add_user_file
echo 'echo ""' >> $add_user_file
echo 'echo "Now, $user can use sftp to access to $user directory"' >> $add_user_file
echo 'echo "Go to localhost/$user to check the welcome page"' >> $add_user_file
chmod +x $add_user_file

echo '#!/bin/bash' > $del_user_file
echo '' >> $del_user_file
echo 'if [ "$(whoami)" != "root" ]; then' >> $del_user_file
echo '  echo "Run script as ROOT please (sudo)"' >> $del_user_file
echo '  exit' >> $del_user_file
echo 'fi' >> $del_user_file
echo '' >> $del_user_file
echo 'read -p "User to delete with directory in /var/www/html: " user' >> $del_user_file
echo '' >> $del_user_file
echo 'userdel $user' >> $del_user_file
echo '' >> $del_user_file
echo 'umount /home/$user/*' >> $del_user_file
echo 'sed -i "/\\/home\/$user/d" /etc/fstab' >> $del_user_file
echo 'rm -rf /var/www/html/$user /home/$user' >> $del_user_file
echo $permissions_file >> $del_user_file
echo '' >> $del_user_file
echo 'echo "Tape your pass to be connected on mysql as root"' >> $del_user_file
echo 'mysql -u root -e "FLUSH PRIVILEGES;DROP DATABASE $user;DROP USER \"$user\"@\"%\"" -p' >> $del_user_file
echo '' >> $del_user_file
echo 'echo ""' >> $del_user_file
echo 'echo ""' >> $del_user_file
echo 'echo "Now, $user is deleted"' >> $del_user_file
echo 'echo "Go to localhost/$user to check they are no more pages"' >> $del_user_file
chmod +x $del_user_file

echo '#!/bin/bash' > $firewall_file
echo '' >> $firewall_file
echo '### BEGIN INIT INFO' >> $firewall_file
echo '# Provides:	firewall' >> $firewall_file
echo '# Required-Start:	$remote_fs $syslog' >> $firewall_file
echo '# Required-Stop:	$remote_fs $syslog' >> $firewall_file
echo '# Default-Start:	2 3 4 5' >> $firewall_file
echo '# Default-Stop:	0 1 6' >> $firewall_file
echo '# Short-Description:	Iptables' >> $firewall_file
echo '# Description:	Load all ip rules set for the server' >> $firewall_file
echo '### END INIT INFO' >> $firewall_file
echo '' >> $firewall_file
echo '' >> $firewall_file
echo 'if [ "$(whoami)" != "root" ]; then' >> $firewall_file
echo '  echo "Run script as ROOT please (sudo)"' >> $firewall_file
echo '  exit' >> $firewall_file
echo 'fi' >> $firewall_file
echo '' >> $firewall_file
echo 'apt-get -y install iptables portsentry fail2ban rkhunter' >> $firewall_file
echo '' >> $firewall_file
echo '# Initialisation' >> $firewall_file
echo "SSH='$SSH'" >> $firewall_file
echo 'sed -i "s/^\(KILL_HOSTS_DENY\)/#\1/" /etc/portsentry/portsentry.conf' >> $firewall_file
echo "sed -i 's/^#\(KILL_ROUTE=\"\/sbin\/iptables -I INPUT -s \$TARGET\$ -j DROP\"\)/\1/' /etc/portsentry/portsentry.conf" >> $firewall_file
echo 'sed -i "s/^port.*= ssh$/port	= $SSH/" /etc/fail2ban/jail.conf' >> $firewall_file
echo 'sed -i "s/^CRON_DAILY_RUN=""$/CRON_DAILY_RUN="yes"/" /etc/default/rkhunter' >> $firewall_file
echo "/etc/init.d/fail2ban restart" >> $firewall_file
echo '' >> $firewall_file
echo '# Delete all rules' >> $firewall_file
echo 'iptables -t filter -F' >> $firewall_file
echo 'iptables -t filter -X' >> $firewall_file
echo '' >> $firewall_file
echo '# Block all requests' >> $firewall_file
echo 'iptables -t filter -P INPUT DROP' >> $firewall_file
echo 'iptables -t filter -P FORWARD DROP' >> $firewall_file
echo 'iptables -t filter -P OUTPUT DROP' >> $firewall_file
echo '' >> $firewall_file
echo "# Don't end already established connexions" >> $firewall_file
echo 'iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT' >> $firewall_file
echo 'iptables -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT' >> $firewall_file
echo '' >> $firewall_file
echo '# Allow ping requests' >> $firewall_file
echo 'iptables -t filter -A INPUT -p icmp -j ACCEPT' >> $firewall_file
echo 'iptables -t filter -A OUTPUT -p icmp -j ACCEPT' >> $firewall_file
echo '' >> $firewall_file
echo '# Allow localhost requests' >> $firewall_file
echo 'iptables -t filter -A INPUT -i lo -j ACCEPT' >> $firewall_file
echo 'iptables -t filter -A OUTPUT -o lo -j ACCEPT' >> $firewall_file
echo '' >> $firewall_file
echo '# Allow HTTP requests' >> $firewall_file
echo 'iptables -t filter -A INPUT -p tcp --dport 80 -j ACCEPT' >> $firewall_file
echo 'iptables -t filter -A OUTPUT -p tcp --dport 80 -j ACCEPT' >> $firewall_file
echo '' >> $firewall_file
echo '# Allow HTTPS requests' >> $firewall_file
echo 'iptables -t filter -A INPUT -p tcp --dport 443 -j ACCEPT' >> $firewall_file
echo 'iptables -t filter -A OUTPUT -p tcp --dport 443 -j ACCEPT' >> $firewall_file
echo '' >> $firewall_file
echo '# Allow DNS requests' >> $firewall_file
echo 'iptables -t filter -A INPUT -p tcp --dport 53 -j ACCEPT' >> $firewall_file
echo 'iptables -t filter -A INPUT -p udp --dport 53 -j ACCEPT' >> $firewall_file
echo 'iptables -t filter -A OUTPUT -p tcp --dport 53 -j ACCEPT' >> $firewall_file
echo 'iptables -t filter -A OUTPUT -p udp --dport 53 -j ACCEPT' >> $firewall_file
echo '' >> $firewall_file
echo '# Allow SSH requests' >> $firewall_file
echo 'iptables -t filter -A INPUT -p tcp --dport $SSH -j ACCEPT' >> $firewall_file
echo '# Allow only local SSH: iptables -t filter -A INPUT -p tcp -m iprange --src-range 192.168.1.0-192.168.1.255 --dport $SSH -j ACCEPT' >> $firewall_file
echo 'iptables -t filter -A OUTPUT -p tcp --dport $SSH -j ACCEPT' >> $firewall_file
echo '' >> $firewall_file
echo '# Allow getting current time' >> $firewall_file
echo 'iptables -t filter -A OUTPUT -p udp --dport 123 -j ACCEPT' >> $firewall_file
echo '' >> $firewall_file
echo '# Prevention from DDos' >> $firewall_file
echo 'iptables -A FORWARD -p tcp --tcp-flags SYN,ACK,FIN,RST RST -m limit --limit 1/second -j ACCEPT' >> $firewall_file
echo 'iptables -A FORWARD -p udp -m limit --limit 1/second -j ACCEPT' >> $firewall_file
echo 'iptables -A FORWARD -p icmp --icmp-type echo-request -m limit --limit 1/second -j ACCEPT' >> $firewall_file
echo 'portsentry –audp' >> $firewall_file
echo 'portsentry –atcp' >> $firewall_file
echo '' >> $firewall_file
echo '# IPs banned' >> $firewall_file
echo '# iptables -A INPUT -s ip_adress -j DROP' >> $firewall_file
chmod +x $firewall_file

ln -s $firewall_file /etc/init.d/firewall
update-rc.d firewall defaults

$firewall_file
$permissions_file

echo '' >> $apache_file
echo '# Stop sending information' >> $apache_file
echo 'ServerSignature off' >> $apache_file
echo 'ServerTokens Prod' >> $apache_file

systemctl enable ssh
/etc/init.d/ssh restart
apachectl restart

echo ''
echo ''
echo 'Portsentry, Jail2ban and Rkhunter installed and run'
echo "SSH restarted with port: $SSH"
echo 'SFTP available. You can add or remove users with directory in /var/www/html/ with add-sftp.sh or del-sftp.sh'
echo 'IP rules updated'
echo 'Apache2 do not send anymore useless informations'
