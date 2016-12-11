#!/bin/bash
source incl/include.sh

apt-get -y update
apt-get -y upgrade
apt-get -y dist-upgrade

apt-get -y install rpi-update

apt-get -y autoremove
apt-get -y install -f
apt-get -y autoremove

#usermod -a -G www-data pi

reboot
