server_name="$HOSTNAME"
local_ip=$(ifconfig | grep 'inet adr:192' | sed -e 's/^.*inet adr:\([0-9\.]*\).*/\1/')

www_dir="/var/www"
web_dir="$www_dir/html"
nextcloud_name="cloud"
nextcloud_web_dir="../$nextcloud_name"
nextcloud_dir="$www_dir/$nextcloud_name"
script_dir="$www_dir/script"
update_file="$script_dir/update.sh"
update_permissions_file="$script_dir/update_permissions.sh"

user="pi"
web_user="www-data"

apache_dir="/etc/apache2"
apache_enabled_dir="$apache_dir/sites-enabled"
apache_available_dir="$apache_dir/sites-available"
apache_config_file="$apache_dir/apache2.conf"

phpmyadmin_file="/etc/phpmyadmin/apache.conf"
