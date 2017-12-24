#!/bin/bash
source incl/include.sh

echo $hostname > /etc/hostname
echo "127.0.0.1	$server_name" >> /etc/hosts

modprobe ipv6
echo "ipv6" >> /etc/modules

useradd -m $ssh_user -s /bin/bash
usermod -a -G $(groups pi | sed "s/^.*: //" | sed "s/ /,/g") $ssh_user
echo -e "Note: You will need to redirect 22 port to access at your server with SSH.
We will create a new user for ssh connexion: $ssh_user
Password for $ssh_user user:"
passwd $ssh_user

echo -e "Root connection will be disabled"
sed -i 's/\(root.*\)bin\/.*/\1bin\/false/' /etc/passwd

echo -e "Wifi and Bluetooth will be disabled (enable by deleting or commenting lines in /etc/modprobe.d/raspi-blacklist.conf)"
cp skeleton/etc/raspi-blacklist.conf /etc/modprobe.d/raspi-blacklist.conf
sudo systemctl stop hciuart
sudo systemctl disable hciuart

apt-get --assume-yes remove apt-listchanges

<<<<<<< HEAD
# No more useful
=======
>>>>>>> 4e939f6f3a8d8705041acd464f1fb02c8f7929b6
#sed -i "s/#^deb-src /deb-src /" /etc/apt/sources.list
# echo -e "# Add directory for PHP7 and update to Stretch version
# deb http://mirrordirector.raspbian.org/raspbian/ stretch main contrib non-free rpi" > /etc/apt/sources.list.d/stretch.list

#curl https://packages.gitlab.com/gpg.key | sudo apt-key add -
#sudo curl -o /etc/apt/sources.list.d/gitlab_ce.list "https://packages.gitlab.com/install/repositories/gitlab/raspberry-pi2/config_file.list?os=debian&dist=jessie"
# Add sources for FastCGI
#deb-src http://mirrordirector.raspbian.org/raspbian/ jessie main contrib non-free rpi
#deb-src http://mirrordirector.raspbian.org/raspbian/ testing main contrib non-free rpi" >> /etc/apt/sources.list

apt-get --assume-yes update

apt-get --assume-yes upgrade
apt-get --assume-yes dist-upgrade
apt-get --assume-yes update
apt-get --assume-yes install iptables
apt-get --assume-yes install portsentry fail2ban rkhunter
apt-get --assume-yes install -f
apt-get --assume-yes autoremove

cp -rf /home/pi/ /home/$ssh_user/
chown -R $ssh_user:$ssh_user /home/$ssh_user/
mkdir $script_dir
cp -rf incl $script_dir/
cp -rf skeleton $script_dir/

cp -rf skeleton/etc/firewall /etc/init.d/firewall
sed -i "s/\$ssh_port/$ssh_port/" /etc/init.d/firewall
chmod +x /etc/init.d/firewall
ln -s /etc/init.d/firewall $update_firewall_file

update-rc.d firewall defaults
$update_firewall_file

apt-get --assume-yes install rpi-update needrestart cron-apt git apt-listchanges

#sed -i "s/^\(KILL_HOSTS_DENY\)/#\1/" /etc/portsentry/portsentry.conf
#sed -i 's/^#\(KILL_ROUTE="\/sbin\/iptables -I INPUT -s \$TARGET\$ -j DROP"\)/\1/' /etc/portsentry/portsentry.conf
#sed -i "s/^CRON_DAILY_RUN=\"\"$/CRON_DAILY_RUN=\"yes\"/" /etc/default/rkhunter
#sed -i "s/^port.*= ssh$/port	= $ssh_port/" /etc/fail2ban/jail.conf
#/etc/init.d/fail2ban restart

systemctl enable ssh
sed -i "s/^Port 22/Port $ssh_port/" $ssh_file
sed -i "s/^PermitRootLogin without-password/PermitRootLogin no/" $ssh_file
sed -i "s/^Subsystem sftp/#Subsystem sftp/" $ssh_file
#sed -i "s/^UsePAM yes/#UsePAM yes/" $ssh_file

sed -i 's/\(pi.*\)bin\/.*/\1bin\/false/' /etc/passwd

echo -e "Now, press enter to poweroff. Then, plug your HDD to your Rpi and connect with SSH with your SSH login: $ssh_user. Finally, launch init_final.sh to finalize the initialisation"
read wait
poweroff
