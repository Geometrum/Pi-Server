#!/bin/bash
source incl/include.sh

apt-get -y update

apt-get -y upgrade
apt-get -y dist-upgrade
apt-get -y install -f
apt-get -y autoremove

deluser --remove-all-files pi 2>&1 /dev/null
rm -rf /home/pi 2>&1 /dev/null

echo -e "
pi user has been removed definitely
Now, press enter to reboot and start use your Rpi like a server by using install_server.sh (will install php, apache, mysql, letsencrypt)"
read wait
reboot
