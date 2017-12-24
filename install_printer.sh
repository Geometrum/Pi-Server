#!/bin/bash
source incl/include.sh

apt-get -y update
apt-get -y install cups cups-pdf sane sane-utils

sed -i "s|Listen localhost:631|Listen *:631|" /etc/cups/cupsd.conf
sed -i "s|</Location>|Allow @local\n</Location>|g" /etc/cups/cupsd.conf

echo -e "
# Allow CUPS requests
iptables -t filter -A INPUT -p tcp --dport 631 -j ACCEPT
iptables -t filter -A OUTPUT -p tcp --dport 631 -j ACCEPT" >> /etc/init.d/firewall
$update_firewall_file

echo -e "
192.168.0.0/24
192.168.1.0/24" >> /etc/sane.d/saned.conf
sed -i "s|RUN=no|RUN=yes|g" /etc/default/saned

cp -rf $script_dir/skeleton/scan $scan_dir
chown -R www-data:www-data $scan_dir

#chmod +s /usr/bin/scanimage
chmod 775 $scan_dir/tmp
chmod 775 $scan_dir/output
chmod 775 $scan_dir/scanners

adduser $ssh_user lpadmin
adduser $web_user lpadmin
adduser $ssh_user lp
adduser $web_user lp
adduser $ssh_user saned
adduser $web_user saned

systemctl enable saned.socket
systemctl daemon-reload
systemctl start saned.socket
service cups restart

scanimage -L
sane-find-scanner

echo -e "

Now, cups and sane are installed.
A reboot is necessary to apply modifications.
You could go to http://$local_ip:631/ to manage cups and printers (yourPrinter)
By going to $scan_dir, you will be able to scan any documents from any local computer
From Linux: scanimage (-L to see all printers)
From Windows: add a local network printer and tap: http://$local_ip:631/printers/yourPrinter
Bonus: Install \"Let's Print Droid\" to print from your Android phone via Wi-Fi"
