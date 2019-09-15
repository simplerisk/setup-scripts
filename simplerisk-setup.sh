#!/bin/bash


###########################################
# SIMPLERISK SETUP SCRIPT FOR UBUNTU 18.04
# Run as root or insert `sudo -E` before `bash`: 
# curl -sL https://raw.githubusercontent.com/simplerisk/setup-scripts/master/simplerisk-setup.sh | bash -
# OR
# wget -qO- https://raw.githubusercontent.com/simplerisk/setup-scripts/master/simplerisk-setup.sh | bash -
###########################################
set +e
export DEBIAN_FRONTEND=noninteractive

print_status() {
	echo
	echo "## $1"
	echo
}

exec_cmd(){
	exec_cmd_nobail "$1" || bail
}

bail() {
	echo 'Error executing command, exiting'
	exit 1
}

exec_cmd_nobail() {
	echo "+ $1"
	bash -c "$1"
}

check_root() {
	## Check to make sure we are running as root
	if [[ $EUID -ne 0 ]]; then
		print_status "ERROR: This script must be run as root!"
		print_status "Try running the command 'sudo bash' and then run this script again..."
		exit 1
	fi
}

setup_ubuntu_1804(){
	# Get the current SimpleRisk release version
	CURRENT_SIMPLERISK_VERSION=`curl -sL https://updates.simplerisk.com/Current_Version.xml | grep -oP '<appversion>(.*)</appversion>' | cut -d '>' -f 2 | cut -d '<' -f 1`

	print_status "Running SimpleRisk ${CURRENT_SIMPLERISK_VERSION} installer..."

	print_status "Populating apt-get cache..."
	exec_cmd 'apt-get update > /dev/null 2>&1'

	print_status "Updating current packages (this may take a bit)..."
	exec_cmd 'apt-get dist-upgrade -qq --force-yes > /dev/null 2>&1'

	print_status "Installing tasksel..."
	exec_cmd "apt-get install -y tasksel > /dev/null 2>&1"

	print_status "Installing lamp-server..."
	exec_cmd "tasksel install lamp-server > /dev/null 2>&1"

	print_status "Installing mbstring module for PHP..."
	exec_cmd "apt-get install -y php-mbstring > /dev/null 2>&1"

	print_status "Installing PHP development libraries..."
	exec_cmd "apt-get install -y php-dev > /dev/null 2>&1"

	print_status "Installing pear for PHP..."
	exec_cmd "apt-get install -y php-pear > /dev/null 2>&1"

	print_status "Updating pear for PHP..."
	exec_cmd "pecl channel-update pecl.php.net > /dev/null 2>&1"

	print_status "Installing mcrypt module for PHP..."
	exec_cmd "apt-get install -y libmcrypt-dev > /dev/null 2>&1"
	exec_cmd "pecl install mcrypt-1.0.1 > /dev/null 2>&1"

	print_status "Enabling the mcrypt extension in PHP..."
	# If the mcrypt extenion is not there yet
	if [ ! `grep -q "extension=mcrypt.so" /etc/php/7.2/apache2/php.ini` ]; then
		exec_cmd "sed -i '/^;extension=xsl/a extension=mcrypt.so' /etc/php/7.2/apache2/php.ini > /dev/null 2>&1"
	fi
	if [ ! `grep -q "extension=mcrypt.so" /etc/php/7.2/cli/php.ini` ]; then
		exec_cmd "sed -i '/^;extension=xsl/a extension=mcrypt.so' /etc/php/7.2/cli/php.ini > /dev/null 2>&1"
	fi

	print_status "Installing ldap module for PHP..."
	exec_cmd "apt-get install -y php-ldap > /dev/null 2>&1"

	print_status "Enabling the ldap module in PHP..."
	exec_cmd "phpenmod ldap > /dev/null 2>&1"

	print_status "Enabling SSL for Apache..."
	exec_cmd "a2enmod rewrite > /dev/null 2>&1"
	exec_cmd "a2enmod ssl > /dev/null 2>&1"
	exec_cmd "a2ensite default-ssl > /dev/null 2>&1"

	print_status "Configuring secure settings for Apache..."
	exec_cmd "sed -i 's/SSLProtocol all -SSLv3/SSLProtocol TLSv1.2/g' /etc/apache2/mods-enabled/ssl.conf > /dev/null 2>&1"
	exec_cmd "sed -i 's/#SSLHonorCipherOrder on/SSLHonorCipherOrder on/g' /etc/apache2/mods-enabled/ssl.conf > /dev/null 2>&1"
	exec_cmd "sed -i 's/ServerTokens OS/ServerTokens Prod/g' /etc/apache2/conf-enabled/security.conf > /dev/null 2>&1"
	exec_cmd "sed -i 's/ServerSignature On/ServerSignature Off/g' /etc/apache2/conf-enabled/security.conf > /dev/null 2>&1"

	print_status "Setting the maximum file upload size in PHP to 5MB..."
	exec_cmd "sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 5M/g' /etc/php/7.2/apache2/php.ini > /dev/null 2>&1"

	print_status "Downloading the latest SimpleRisk release to /var/www/simplerisk..."
	exec_cmd "rm -r /var/www/html"
	exec_cmd "cd /var/www && wget https://github.com/simplerisk/bundles/raw/master/simplerisk-${CURRENT_SIMPLERISK_VERSION}.tgz > /dev/null 2>&1"
	exec_cmd "cd /var/www && tar xvzf simplerisk-${CURRENT_SIMPLERISK_VERSION}.tgz > /dev/null 2>&1"
	exec_cmd "rm /var/www/simplerisk-${CURRENT_SIMPLERISK_VERSION}.tgz > /dev/null 2>&1"
	exec_cmd "cd /var/www/simplerisk && wget https://github.com/simplerisk/installer/raw/master/simplerisk-installer-${CURRENT_SIMPLERISK_VERSION}.tgz > /dev/null 2>&1"
	exec_cmd "cd /var/www/simplerisk && tar xvzf simplerisk-installer-${CURRENT_SIMPLERISK_VERSION}.tgz > /dev/null 2>&1"
	exec_cmd "rm /var/www/simplerisk/simplerisk-installer-${CURRENT_SIMPLERISK_VERSION}.tgz > /dev/null 2>&1"

	print_status "Configuring Apache..."
	exec_cmd "sed -i 's/\/var\/www\/html/\/var\/www\/simplerisk/g' /etc/apache2/sites-enabled/000-default.conf > /dev/null 2>&1"
	if [ ! `grep -q "RewriteEngine On" /etc/apache2/sites-enabled/000-default.conf` ]; then
		exec_cmd "sed -i '/^<\/VirtualHost>/i \\\tRewriteEngine On\n\tRewriteCond %{HTTPS} !=on\n\tRewriteRule ^/?(.*) https://%{SERVER_NAME}/$1 [R,L]' /etc/apache2/sites-enabled/000-default.conf > /dev/null 2>&1"
	fi
	exec_cmd "sed -i 's/\/var\/www\/html/\/var\/www\/simplerisk/g' /etc/apache2/sites-enabled/default-ssl.conf > /dev/null 2>&1"
	if [ ! `grep -q "AllowOverride all" /etc/apache2/sites-enabled/default-ssl.conf` ]; then
		exec_cmd "sed -i '/<\/Directory>/a \\\t\t<Directory \"\/var\/www\/simplerisk\">\n\t\t\tAllowOverride all\n\t\t\tallow from all\n\t\t\tOptions -Indexes\n\t\t<\/Directory>' /etc/apache2/sites-enabled/default-ssl.conf > /dev/null 2>&1"
	fi

	print_status "Restarting Apache to load the new configuration..."
	exec_cmd "service apache2 restart > /dev/null 2>&1"

	print_status "Generating MySQL passwords..."
	exec_cmd "apt-get install -y pwgen > /dev/null 2>&1"
	NEW_MYSQL_ROOT_PASSWORD=`pwgen -c -n -1 20` > /dev/null 2>&1
	MYSQL_SIMPLERISK_PASSWORD=`pwgen -c -n -1 20` > /dev/null 2>&1
	echo "MYSQL ROOT PASSWORD: ${NEW_MYSQL_ROOT_PASSWORD}" >> /root/passwords.txt
	echo "MYSQL SIMPLERISK PASSWORD: ${MYSQL_SIMPLERISK_PASSWORD}" >> /root/passwords.txt
	chmod 600 /root/passwords.txt

	print_status "Configuring MySQL..."
	exec_cmd "sed -i '$ a sql-mode=\"STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION\"' /etc/mysql/mysql.conf.d/mysqld.cnf > /dev/null 2>&1"
	exec_cmd "mysql -uroot mysql -e \"CREATE DATABASE simplerisk\""
	exec_cmd "mysql -uroot simplerisk -e \"\\. /var/www/simplerisk/install/db/simplerisk-en-${CURRENT_SIMPLERISK_VERSION}.sql\""
	exec_cmd "mysql -uroot simplerisk -e \"GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, ALTER ON simplerisk.* TO 'simplerisk'@'localhost' IDENTIFIED BY '${MYSQL_SIMPLERISK_PASSWORD}'\""
	exec_cmd "mysql -uroot mysql -e \"ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${NEW_MYSQL_ROOT_PASSWORD}'\""

	print_status "Setting the SimpleRisk database password..."
	exec_cmd "sed -i \"s/DB_PASSWORD', 'simplerisk/DB_PASSWORD', '${MYSQL_SIMPLERISK_PASSWORD}/\" /var/www/simplerisk/includes/config.php > /dev/null 2>&1"

	print_status "Restarting MySQL to load the new configuration..."
	exec_cmd "service mysql restart > /dev/null 2>&1"

	print_status "Removing the SimpleRisk install directory..."
	exec_cmd "rm -r /var/www/simplerisk/install"

	print_status "Enabling UFW firewall..."
	exec_cmd "ufw allow ssh > /dev/null 2>&1"
	exec_cmd "ufw allow http > /dev/null 2>&1"
	exec_cmd "ufw allow https > /dev/null 2>&1"
	exec_cmd "ufw --force enable > /dev/null 2>&1"

	print_status "Check /root/passwords.txt for the MySQL root and simplerisk passwords."
	print_status "INSTALLATION COMPLETED SUCCESSFULLY"
}

setup_centos_7(){
	# Get the current SimpleRisk release version
	CURRENT_SIMPLERISK_VERSION=`curl -sL https://updates.simplerisk.com/Current_Version.xml | grep -oP '<appversion>(.*)</appversion>' | cut -d '>' -f 2 | cut -d '<' -f 1`

	print_status "Running SimpleRisk ${CURRENT_SIMPLERISK_VERSION} installer..."

	print_status "Updating packages with yum..."
	exec_cmd "yum -y --skip-broken --nobest update > /dev/null 2>&1"

	print_status "Installing the Apache web server..."
	exec_cmd "yum -y install httpd > /dev/null 2>&1"

	print_status "Installing PHP for Apache..."
	exec_cmd "yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm"
	exec_cmd "yum -y install yum-utils"
	exec_cmd "subscription-manager  repos --enable=rhel-7-server-optional-rpms"
	exec_cmd "yum-config-manger --enable remi-php72"
	exec_cmd "yum update"
	exec_cmd "yum search php72 | more"
	exec_cmd "yum -y install php72"

	print_status "Enabling and starting the Apache web server..."
	exec_cmd "systemctl enable httpd > /dev/null 2>&1"
	exec_cmd "systemctl start httpd > /dev/null 2>&1"

	print_status "Downloading the latest SimpleRisk release to /var/www/simplerisk..."
	exec_cmd "rm -rf /var/www/html"
	exec_cmd "cd /var/www && wget https://github.com/simplerisk/bundles/raw/master/simplerisk-${CURRENT_SIMPLERISK_VERSION}.tgz > /dev/null 2>&1"
	exec_cmd "cd /var/www && tar xvzf simplerisk-${CURRENT_SIMPLERISK_VERSION}.tgz > /dev/null 2>&1"
	exec_cmd "rm -f /var/www/simplerisk-${CURRENT_SIMPLERISK_VERSION}.tgz > /dev/null 2>&1"
	exec_cmd "cd /var/www/simplerisk && wget https://github.com/simplerisk/installer/raw/master/simplerisk-installer-${CURRENT_SIMPLERISK_VERSION}.tgz > /dev/null 2>&1"
	exec_cmd "cd /var/www/simplerisk && tar xvzf simplerisk-installer-${CURRENT_SIMPLERISK_VERSION}.tgz > /dev/null 2>&1"
	exec_cmd "rm -f /var/www/simplerisk/simplerisk-installer-${CURRENT_SIMPLERISK_VERSION}.tgz > /dev/null 2>&1"
	exec_cmd "chown -R apache: /var/www/simplerisk"

	print_status "Configuring Apache..."
	exec_cmd "cd /etc/httpd && mkdir sites-available"
	exec_cmd "cd /etc/httpd && mkdir sites-enabled"
	exec_cmd "echo \"IncludeOptional sites-enabled/*.conf\" >> /etc/httpd/conf/httpd.conf"
	echo "<VirtualHost *:80>" >> /etc/httpd/sites-enabled/simplerisk.conf
	echo "  DocumentRoot \"/var/www/simplerisk/\"" >> /etc/httpd/sites-enabled/simplerisk.conf
	echo "  <Directory \"/var/www/simplerisk/\">" >> /etc/httpd/sites-enabled/simplerisk.conf
	echo "    AllowOverride all" >> /etc/httpd/sites-enabled/simplerisk.conf
	echo "    allow from all" >> /etc/httpd/sites-enabled/simplerisk.conf
	echo "    Options -Indexes" >> /etc/httpd/sites-enabled/simplerisk.conf
	echo "  </Directory>" >> /etc/httpd/sites-enabled/simplerisk.conf
	echo "  RewriteEngine On" >> /etc/httpd/sites-enabled/simplerisk.conf
	echo "  RewriteCond %{HTTPS} off [OR]" >> /etc/httpd/sites-enabled/simplerisk.conf
	echo "  RewriteRule ^/(.*) https://%{HTTPS_HOST}/$1 [NC,R=301,L]" >> /etc/httpd/sites-enabled/simplerisk.conf
	echo "</VirtualHost>" >> /etc/httpd/sites-enabled/simplerisk.conf

	    if [ ! `grep -q "AllowOverride all" /etc/httpd/conf.d/ssl.conf` ]; then
        exec_cmd "sed -i '/<\/Directory>/a \\\t\t<Directory \"\/var\/www\/simplerisk\">\n\t\t\tAllowOverride all\n\t\t\tallow from all\n\t\t\tOptions -Indexes\n\t\t<\/Directory>' /etc/httpd/con.f/ssl.conf > /dev/null 2>&1"
    fi

	print_status "Installing the MariaDB database server..."
	exec_cmd "yum -y install mariadb-server > /dev/null 2>&1"

	print_status "Enabling and starting the MariaDB database server..."
	exec_cmd "systemctl enable mariadb > /dev/null 2>&1"
	exec_cmd "systemctl start mariadb > /dev/null 2>&1"

	print_status "Generating MySQL passwords..."
	NEW_MYSQL_ROOT_PASSWORD=`< /dev/urandom tr -dc A-Za-z0-9 | head -c20` > /dev/null 2>&1
	MYSQL_SIMPLERISK_PASSWORD=`< /dev/urandom tr -dc A-Za-z0-9 | head -c20` > /dev/null 2>&1
	echo "MYSQL ROOT PASSWORD: ${NEW_MYSQL_ROOT_PASSWORD}" >> /root/passwords.txt
	echo "MYSQL SIMPLERISK PASSWORD: ${MYSQL_SIMPLERISK_PASSWORD}" >> /root/passwords.txt
	chmod 600 /root/passwords.txt

	print_status "Configuring MySQL..."
	#exec_cmd "sed -i '$ a sql-mode=\"STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION\"' /etc/mysql/mysql.conf.d/mysqld.cnf > /dev/null 2>&1"
	exec_cmd "mysql -uroot mysql -e \"CREATE DATABASE simplerisk\""
	exec_cmd "mysql -uroot simplerisk -e \"\\. /var/www/simplerisk/install/db/simplerisk-en-${CURRENT_SIMPLERISK_VERSION}.sql\""
	exec_cmd "mysql -uroot simplerisk -e \"GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, ALTER ON simplerisk.* TO 'simplerisk'@'localhost' IDENTIFIED BY '${MYSQL_SIMPLERISK_PASSWORD}'\""
	exec_cmd "mysql -uroot mysql -e \"DROP DATABASE test\""
	exec_cmd "mysql -uroot mysql -e \"DROP USER ''@'localhost'\""
	exec_cmd "mysql -uroot mysql -e \"DROP USER ''@'$(hostname)'\""
	exec_cmd "mysql -uroot mysql -e \"UPDATE mysql.user SET Password = PASSWORD('${NEW_MYSQL_ROOT_PASSWORD}') WHERE User = 'root'\""
	#exec_cmd "mysql -uroot mysql -e \"ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${NEW_MYSQL_ROOT_PASSWORD}'\""

	print_status "Setting the SimpleRisk database password..."
	exec_cmd "sed -i \"s/DB_PASSWORD', 'simplerisk/DB_PASSWORD', '${MYSQL_SIMPLERISK_PASSWORD}/\" /var/www/simplerisk/includes/config.php > /dev/null 2>&1"

	print_status "Restarting MySQL to load the new configuration..."
	exec_cmd "systemctl restart mariadb > /dev/null 2>&1"

	print_status "Removing the SimpleRisk install directory..."
	exec_cmd "rm -r /var/www/simplerisk/install"

	print_status "Check /root/passwords.txt for the MySQL root and simplerisk passwords."
	print_status "INSTALLATION COMPLETED SUCCESSFULLY"
}

setup_rhel_8(){
	# Get the current SimpleRisk release version
	CURRENT_SIMPLERISK_VERSION=`curl -sL https://updates.simplerisk.com/Current_Version.xml | grep -oP '<appversion>(.*)</appversion>' | cut -d '>' -f 2 | cut -d '<' -f 1`

	print_status "Running SimpleRisk ${CURRENT_SIMPLERISK_VERSION} installer..."

	print_status "Updating packages with yum.  This can take several minutes to complete..."
	exec_cmd "yum -y update > /dev/null 2>&1"

	print_status "Installing the wget package..."
	exec_cmd "yum -y install wget > /dev/null 2>&1"
	
	print_status "Installing Firewalld"
	exec_cmd "yum -y install firewalld > /dev/null 2>&1"

	print_status "Installing the Apache web server..."
	exec_cmd "yum -y install httpd > /dev/null 2>&1"

	print_status "Installing PHP for Apache..."
	exec_cmd "yum -y install php php-mysqlnd php-mbstring php-opcache php-gd php-json php-ldap > /dev/null 2>&1"
	
	print_status "Installing the MariaDB database server..."
	exec_cmd "yum -y install mariadb-server > /dev/null 2>&1"
	
	print_status "Installing mod_ssl"
	exec_cmd "yum -y install mod_ssl > /dev/null 2>&1"

	print_status "Enabling and starting the Apache web server..."
	exec_cmd "systemctl enable httpd > /dev/null 2>&1"
	exec_cmd "systemctl start httpd > /dev/null 2>&1"

	print_status "Downloading the latest SimpleRisk release to /var/www/simplerisk..."
	#exec_cmd "rm -rf /var/www/html > /dev/null 2>&1"
	exec_cmd "cd /var/www && wget https://github.com/simplerisk/bundles/raw/master/simplerisk-${CURRENT_SIMPLERISK_VERSION}.tgz > /dev/null 2>&1"
	exec_cmd "cd /var/www && tar xvzf simplerisk-${CURRENT_SIMPLERISK_VERSION}.tgz > /dev/null 2>&1"
	exec_cmd "rm -f /var/www/simplerisk-${CURRENT_SIMPLERISK_VERSION}.tgz > /dev/null 2>&1"
	exec_cmd "cd /var/www/simplerisk && wget https://github.com/simplerisk/installer/raw/master/simplerisk-installer-${CURRENT_SIMPLERISK_VERSION}.tgz > /dev/null 2>&1"
	exec_cmd "cd /var/www/simplerisk && tar xvzf simplerisk-installer-${CURRENT_SIMPLERISK_VERSION}.tgz > /dev/null 2>&1"
	exec_cmd "rm -f /var/www/simplerisk/simplerisk-installer-${CURRENT_SIMPLERISK_VERSION}.tgz > /dev/null 2>&1"
	exec_cmd "chown -R apache: /var/www/simplerisk"

	print_status "Configuring Apache..."
	exec_cmd "sed -i 's/#DocumentRoot \"\/var\/www\/html\"/DocumentRoot \"\/var\/www\/simplerisk\"/' /etc/httpd/conf.d/ssl.conf"
	exec_cmd "cd /etc/httpd && mkdir sites-available"
	exec_cmd "cd /etc/httpd && mkdir sites-enabled"
	exec_cmd "echo \"IncludeOptional sites-enabled/*.conf\" >> /etc/httpd/conf/httpd.conf"
	echo "<VirtualHost *:80>" >> /etc/httpd/sites-enabled/simplerisk.conf
	echo "  DocumentRoot \"/var/www/simplerisk/\"" >> /etc/httpd/sites-enabled/simplerisk.conf
	echo "  ErrorLog /var/log/httpd/error_log" >> /etc/httpd/sites-enabled/simplerisk.conf
	echo "  CustomLog /var/log/httpd/access_log combined" >> /etc/httpd/sites-enabled/simplerisk.conf
	echo "  <Directory \"/var/www/simplerisk/\">" >> /etc/httpd/sites-enabled/simplerisk.conf
	echo "    AllowOverride all" >> /etc/httpd/sites-enabled/simplerisk.conf
	echo "    allow from all" >> /etc/httpd/sites-enabled/simplerisk.conf
	echo "    Options -Indexes" >> /etc/httpd/sites-enabled/simplerisk.conf
	echo "  </Directory>" >> /etc/httpd/sites-enabled/simplerisk.conf
	echo "  RewriteEngine On" >> /etc/httpd/sites-enabled/simplerisk.conf
	echo "  RewriteCond %{HTTPS} !=on" >> /etc/httpd/sites-enabled/simplerisk.conf
	echo "  RewriteRule ^/?(.*) https://%{SERVER_NAME}/$1 [R,L]" >> /etc/httpd/sites-enabled/simplerisk.conf
	echo "</VirtualHost>" >> /etc/httpd/sites-enabled/simplerisk.conf
	
	if [ ! `grep -q "AllowOverride all" /etc/httpd/conf.d/ssl.conf` ]; then
    exec_cmd "sed -i '/<\/Directory>/a \\\t\t<Directory \"\/var\/www\/simplerisk\">\n\t\t\tAllowOverride all\n\t\t\tallow from all\n\t\t\tOptions -Indexes\n\t\t<\/Directory>' /etc/httpd/conf.d/ssl.conf > /dev/null 2>&1"
    fi
	print_status "Enabling and starting the MariaDB database server..."
	exec_cmd "systemctl enable mariadb > /dev/null 2>&1"
	exec_cmd "systemctl start mariadb > /dev/null 2>&1"

	print_status "Generating MySQL passwords..."
	NEW_MYSQL_ROOT_PASSWORD=`< /dev/urandom tr -dc A-Za-z0-9 | head -c20` > /dev/null 2>&1
	MYSQL_SIMPLERISK_PASSWORD=`< /dev/urandom tr -dc A-Za-z0-9 | head -c20` > /dev/null 2>&1
	echo "MYSQL ROOT PASSWORD: ${NEW_MYSQL_ROOT_PASSWORD}" >> /root/passwords.txt
	echo "MYSQL SIMPLERISK PASSWORD: ${MYSQL_SIMPLERISK_PASSWORD}" >> /root/passwords.txt
	chmod 600 /root/passwords.txt

	print_status "Configuring MySQL..."
	#exec_cmd "sed -i '$ a sql-mode=\"STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION\"' /etc/mysql/mysql.conf.d/mysqld.cnf > /dev/null 2>&1"
	exec_cmd "mysql -uroot mysql -e \"CREATE DATABASE simplerisk\""
	exec_cmd "mysql -uroot simplerisk -e \"\\. /var/www/simplerisk/install/db/simplerisk-en-${CURRENT_SIMPLERISK_VERSION}.sql\""
	exec_cmd "mysql -uroot simplerisk -e \"GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, ALTER ON simplerisk.* TO 'simplerisk'@'localhost' IDENTIFIED BY '${MYSQL_SIMPLERISK_PASSWORD}'\""
	#exec_cmd "mysql -uroot mysql -e \"DROP DATABASE test\""
	#exec_cmd "mysql -uroot mysql -e \"DROP USER ''@'localhost'\""
	#exec_cmd "mysql -uroot mysql -e \"DROP USER ''@'$(hostname)'\""
	exec_cmd "mysql -uroot mysql -e \"UPDATE mysql.user SET Password = PASSWORD('${NEW_MYSQL_ROOT_PASSWORD}') WHERE User = 'root'\""
	#exec_cmd "mysql -uroot mysql -e \"ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${NEW_MYSQL_ROOT_PASSWORD}'\""

	print_status "Setting the SimpleRisk database password..."
	exec_cmd "sed -i \"s/DB_PASSWORD', 'simplerisk/DB_PASSWORD', '${MYSQL_SIMPLERISK_PASSWORD}/\" /var/www/simplerisk/includes/config.php > /dev/null 2>&1"

	print_status "Restarting MySQL to load the new configuration..."
	exec_cmd "systemctl restart mariadb > /dev/null 2>&1"

	print_status "Removing the SimpleRisk install directory..."
	exec_cmd "rm -r /var/www/simplerisk/install"
		
	print_status "Restarting Apache..."
	exec_cmd "systemctl restart httpd"

	#print_status "Disabling SELinux..."
	#exec_cmd "sed -i \"s/SELINUX=enforcing/SELINUX=disabled/\" /etc/sysconfig/selinux > /dev/null 2>&1"
	#exec_cmd "setenforce 0"
		
	print_status "Opening Firewall for HTTP/HTTPS traffic"
	exec_cmd "systemctl enable firewalld"
	exec_cmd "systemctl start firewalld"
	exec_cmd "firewall-cmd --permanent --zone=public --add-service=http" 
	exec_cmd "firewall-cmd --permanent --zone=public --add-service=https"
	exec_cmd "firewall-cmd --permanent --zone=public --add-service=ssh"
	exec_cmd "firewall-cmd --reload"
	
	print_status "Configuring SELinux for SimpleRisk"
	exec_cmd "setsebool -P httpd_builtin_scripting=1"
	exec_cmd "setsebool -P httpd_can_network_connect=1"
	exec_cmd "setsebool -P httpd_can_sendmail=1"
	exec_cmd "setsebool -P httpd_dbus_avahi=1"
	exec_cmd "setsebool -P httpd_enable_cgi=1"
	exec_cmd "setsebool -P httpd_read_user_content=1"
	exec_cmd "setsebool -P httpd_tty_comm=1"
	exec_cmd "setsebool -P allow_httpd_anon_write=0"
	exec_cmd "setsebool -P allow_httpd_mod_auth_ntlm_winbind=0"
	exec_cmd "setsebool -P allow_httpd_mod_auth_pam=0"
	exec_cmd "setsebool -P allow_httpd_sys_script_anon_write=0"
	exec_cmd "setsebool -P httpd_can_check_spam=0"
	exec_cmd "setsebool -P httpd_can_network_connect_cobbler=0"
	exec_cmd "setsebool -P httpd_can_network_connect_db=0"
	exec_cmd "setsebool -P httpd_can_network_memcache=0"
	exec_cmd "setsebool -P httpd_can_network_relay=0"
	exec_cmd "setsebool -P httpd_dbus_sssd=0"
	exec_cmd "setsebool -P httpd_enable_ftp_server=0"
	exec_cmd "setsebool -P httpd_enable_homedirs=0"
	exec_cmd "setsebool -P httpd_execmem=0"
	exec_cmd "setsebool -P httpd_manage_ipa=0"
	exec_cmd "setsebool -P httpd_run_preupgrade=0"
	exec_cmd "setsebool -P httpd_run_stickshift=0"
	exec_cmd "setsebool -P httpd_serve_cobbler_files=0"
	exec_cmd "setsebool -P httpd_setrlimit=0"
	exec_cmd "setsebool -P httpd_ssi_exec=0"
	exec_cmd "setsebool -P httpd_tmp_exec=0"
	exec_cmd "setsebool -P httpd_use_cifs=0"
	exec_cmd "setsebool -P httpd_use_fusefs=0"
	exec_cmd "setsebool -P httpd_use_gpg=0"
	exec_cmd "setsebool -P httpd_use_nfs=0"
	exec_cmd "setsebool -P httpd_use_openstack=0"
	exec_cmd "setsebool -P httpd_verify_dns=0"

	
	
		
	print_status "Check /root/passwords.txt for the MySQL root and simplerisk passwords."
	print_status "INSTALLATION COMPLETED SUCCESSFULLY"
}

setup(){
	# Check to make sure we are running as root
	check_root

	read -p "This script will install SimpleRisk on this sytem.  Are you sure that you would like to proceed? [ Yes / No ]: " answer < /dev/tty
	case $answer in
		Yes|yes|Y|y ) os_detect;;
		* ) exit 1;;
	esac
}

os_detect(){
	if [ -f /etc/os-release ]; then
		# freedesktop.org and systemd
		. /etc/os-release
		OS=$NAME
		VER=$VERSION_ID
	elif type lsb_release >/dev/null 2>&1; then
		# linuxbase.org
		OS=$(lsb_release -si)
		VER=$(lsb_release -sr)
	elif [ -f /etc/lsb-release ]; then
		# For some versions of Debian/Ubuntu without lsb_release command
		. /etc/lsb-release
		OS=$DISTRIB_ID
		VER=$DISTRIB_RELEASE
	elif [ -f /etc/debian_version ]; then
		# Older Debian/Ubuntu/etc.
		OS=Debian
		VER=$(cat /etc/debian_version)
	elif [ -f /etc/SuSe-release ]; then
		# Older SuSE/etc.
                echo "The SimpleRisk setup script cannot reliably determine which commands to run for this OS.  Exiting."
                exit 1
	elif [ -f /etc/redhat-release ]; then
		# Older Red Hat, CentOS, etc.
                echo "The SimpleRisk setup script cannot reliably determine which commands to run for this OS.  Exiting."
                exit 1
	else
		# Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
		OS=$(uname -s)
		VER=$(uname -r)
	fi

	if [ "$OS" = "Ubuntu" ]; then
		if [ "$VER" = "18.04" ]; then
			echo "Detected that we are running ${OS} ${VER}.  Continuing with SimpleRisk setup."
			setup_ubuntu_1804
		fi
	elif [ "$OS" = "CentOS Linux" ]; then
		if [ "$VER" = "7" ]; then
			echo "Detected that we are running ${OS} ${VER}.  Continuing with SimpleRisk setup."
			setup_centos_7
		fi
	elif [  "$OS" = "Red Hat Enterprise Linux" ]; then
		if [ "$VER" = "8.0" ]; then
			echo "Detected that we are running ${OS} ${VER}. Continuing with SimpleRisk Setup."
			setup_rhel_8
		fi
	else
		echo "The SimpleRisk setup script cannot reliably determine which commands to run for this OS.  Exiting."
		exit 1
	fi
}

## Defer setup until we have the complete script
setup
