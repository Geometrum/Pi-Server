#!/bin/bash
source incl/include.sh

apt-get -y update

apt-get -y upgrade
apt-get -y dist-upgrade
apt-get -y install -f
apt-get -y autoremove

deluser --remove-all-files pi 2>&1 /dev/null
rm -rf /home/pi 2>&1 /dev/null

echo -e "Now, press enter to reboot and start use your Rpi like a server"
read wait
reboot
