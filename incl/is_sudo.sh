#/bin/bash

if [ "$(whoami)" != 'root' ]; then
	echo 'You must run this script as root. Use sudo !'
	exit
fi
