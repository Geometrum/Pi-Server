

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
chmod +x $del_user_files

/etc/init.d/ssh restart
systemctl daemon-reload && /etc/init.d/apache2 restart

echo -e "

Portsentry, Jail2ban and Rkhunter installed and run
SSH restarted with port: $SSH
SFTP available. You can add or remove users with directory in $web_dir with $add_user_file or $del_user_file
IP rules updated
Apache2 do not send anymore useless informations"
