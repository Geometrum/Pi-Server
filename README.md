# Pi-Server
Raspberry Pi 3 (Raspbian) - Apache2 + MySQL + PHPMyAdmin + NextCloud + SSL + SSH/SFTP

INSTALLATION FILES:
 - Start with init.sh to update your system
 - Run install.sh to install all features neccessary for the server + NextCloud

Info: install.sh create two files:
  * /var/www/update.sh: Update Apache2, PHP, MySQL and PHPMyAdmin 
  * /var/www/update-permissions.sh: Update all permissions files under /var/www


OPTIONAL:
 - If you want to allow your server to be accessible from internet, run internet.sh (allow only SSL requests, otherwise if a HTTP request is made, redirection to HTTPS)

Info: internet.sh create one file:
  * /var/www/update-SSL.sh: Update the SSL certification

  - If you want to allow SSH/SFTP interactions, run interactions.sh to start enable SSH/SFTP, configure it and have the possibility to manage users (create subdirectory under /var/www/html and allow SFTP access)

Info: interactions.sh create two files:
  * /var/www/add-sftp.sh: Create a new user with a password. This new user has a directory in /var/www/html/$user and has the possibility to manage this directory with SFTP
  * /var/www/del-sftp.sh: Delete the given user and the directory /var/www/html/$user
