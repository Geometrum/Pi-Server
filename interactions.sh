#!/bin/bash
source incl/include.sh

echo -e '
'
read -p 'Which port will be used for SSH requests (22): ' SSH

sed -i "s/^Port 22/Port $SSH/" $sshd_file
sed -i "s/^PermitRootLogin without-password/PermitRootLogin no/" $sshd_file
sed -i "s/^Subsystem sftp/#Subsystem sftp/" $sshd_file
sed -i "s/^UsePAM yes/#UsePAM yes/" $sshd_file
echo -e "
# Directory for sftp users
SubSystem sftp internal-sftp
Match User sftp
	ChrootDirectory $www_dir
	ForceCommand internal-sftp
Match Group $web_user
	ChrootDirectory %h
	ForceCommand internal-sftp
AllowGroups $web_user
AllowUser $user" >> $sshd_file

echo -e '

Creation of your sftp account (sftp)'
useradd -g $web_user sftp -s /bin/false
passwd sftp

echo -e "#!/bin/bash
source incl/include.sh

read -p 'New user to create with directory in \$web_dir: ' user

useradd -g \$web_user \$user -s /bin/false
passwd \$user

mkdir /home/\$user/{,html}
ln -s /home/\$user/html \$web_dir/\$user

read -sp \"Password for \$user to connect to phpmyadmin: \" pass
echo 'Tape your pass to be connected on mysql as root'
mysql -u root -e \"FLUSH PRIVILEGES; CREATE DATABASE \$user; GRANT ALL PRIVILEGES ON \$user.* TO \\\"\$user\\\"@\\\"%\\\" IDENTIFIED BY \\\"\$pass\\\";\" -p

chown -R root:\$web_user /home/\$user
chmod 750 /home/\$user
chmod 770 /home/\$user/*
echo \"<?php echo 'Welcome to your directory, \$user'; ?>\" > \$web_dir/\$user/index.php
echo \$permissions_file

echo -e \"

Now, \$user can use sftp to access to \$user directory
Go to localhost/\$user to check the welcome page\"" > $add_user_file
chmod +x $add_user_file

echo -e "#!/bin/bash
source incl/include.sh

read -p \"User to delete with directory in \$web_dir: \" user

userdel \$user

rm -rf /home/\$user \$web_dir/\$user
\$permissions_file

echo \"Tape your pass to be connected on mysql as root\"
mysql -u root -e \"FLUSH PRIVILEGES; DROP DATABASE \$user; DROP USER \\\"\$user\\\"@\\\"%\\\"\" -p

echo -e \"

\$user had been removed
Go to localhost/\$user to check they are no more pages\"" > $del_user_file
chmod +x $del_user_file

echo -e "#!/bin/bash

### BEGIN INIT INFO
# Provides:	firewall
# Required-Start:	\$remote_fs \$syslog
# Required-Stop:	\$remote_fs \$syslog
# Default-Start:	2 3 4 5
# Default-Stop:	0 1 6
# Short-Description:	Iptables
# Description:	Load all ip rules set for the server
### END INIT INFO

apt-get -y install iptables portsentry fail2ban rkhunter

# Initialisation
SSH='$SSH'
sed -i \"s/^\(KILL_HOSTS_DENY\)/#\1/\" /etc/portsentry/portsentry.conf
sed -i 's/^#\(KILL_ROUTE=\"\/sbin\/iptables -I INPUT -s \$TARGET\$ -j DROP\"\)/\1/' /etc/portsentry/portsentry.conf
sed -i \"s/^port.*= ssh$/port	= $SSH/\" /etc/fail2ban/jail.conf
sed -i \"s/^CRON_DAILY_RUN=\"\"$/CRON_DAILY_RUN=\"yes\"/\" /etc/default/rkhunter
/etc/init.d/fail2ban restart

# Delete all rules
iptables -t filter -F
iptables -t filter -X

# Block all requests
iptables -t filter -P INPUT DROP
iptables -t filter -P FORWARD DROP
iptables -t filter -P OUTPUT DROP

# Don't end already established connexions
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

# Allow ping requests
iptables -t filter -A INPUT -p icmp -j ACCEPT
iptables -t filter -A OUTPUT -p icmp -j ACCEPT

# Allow localhost requests
iptables -t filter -A INPUT -i lo -j ACCEPT
iptables -t filter -A OUTPUT -o lo -j ACCEPT

# Allow HTTP requests
iptables -t filter -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -t filter -A OUTPUT -p tcp --dport 80 -j ACCEPT

# Allow HTTPS requests
iptables -t filter -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -t filter -A OUTPUT -p tcp --dport 443 -j ACCEPT

# Allow DNS requests
iptables -t filter -A INPUT -p tcp --dport 53 -j ACCEPT
iptables -t filter -A INPUT -p udp --dport 53 -j ACCEPT
iptables -t filter -A OUTPUT -p tcp --dport 53 -j ACCEPT
iptables -t filter -A OUTPUT -p udp --dport 53 -j ACCEPT

# Allow SSH requests
iptables -t filter -A INPUT -p tcp --dport $SSH -j ACCEPT
# Allow only local SSH: iptables -t filter -A INPUT -p tcp -m iprange --src-range 192.168.1.0-192.168.1.255 --dport $SSH -j ACCEPT
iptables -t filter -A OUTPUT -p tcp --dport $SSH -j ACCEPT

# Allow getting current time
iptables -t filter -A OUTPUT -p udp --dport 123 -j ACCEPT

# Prevention from DDos
iptables -A FORWARD -p tcp --tcp-flags SYN,ACK,FIN,RST RST -m limit --limit 1/second -j ACCEPT
iptables -A FORWARD -p udp -m limit --limit 1/second -j ACCEPT
iptables -A FORWARD -p icmp --icmp-type echo-request -m limit --limit 1/second -j ACCEPT
portsentry –audp
portsentry –atcp

# IPs banned
# iptables -A INPUT -s ip_adress -j DROP" > /etc/init.d/firewall
chmod +x /etc/init.d/firewall
ln -s /etc/init.d/firewall $update_firewall_file

update-rc.d firewall defaults

$update_firewall_file
$update_permissions_file

echo -e "
# Stop sending information
ServerSignature off
ServerTokens Prod" >> $apache_config_file

/etc/init.d/ssh restart
systemctl daemon-reload && /etc/init.d/apache2 restart

echo -e "

Portsentry, Jail2ban and Rkhunter installed and run
SSH restarted with port: $SSH
SFTP available. You can add or remove users with directory in $web_dir with $add_user_file or $del_user_file
IP rules updated
Apache2 do not send anymore useless informations"
