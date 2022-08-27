#!/usr/bin/env bash


###########################################
# SIMPLERISK SETUP SCRIPT
# Currently works for:
# - Debian 11
# - Ubuntu 18.04, 20.04, and 22.04
# - CentOS 7, 8
# - Red Hat Enterprise Linux (RHEL) 7.9, 8
# - SUSE Linux Enterprise Server (SLES) 12, 15
#
# Run as root or insert `sudo -E` before `bash`: 
# curl -sL https://raw.githubusercontent.com/simplerisk/setup-scripts/master/simplerisk-setup.sh | bash -
# OR
# wget -qO- https://raw.githubusercontent.com/simplerisk/setup-scripts/master/simplerisk-setup.sh | bash -
###########################################
set -eo pipefail
export DEBIAN_FRONTEND=noninteractive

print_status() {
	echo
	echo "## ${1}"
	echo
}

exec_cmd(){
	exec_cmd_nobail "${1}" || bail
}

bail() {
	echo 'Error executing command, exiting'
	exit 1
}

exec_cmd_nobail() {
	[ -v DEBUG ] || NO_LOG="> /dev/null 2>&1"
	echo "+ ${1} ${NO_LOG:-}"
	bash -c "${1} ${NO_LOG:-}"
}

check_root() {
	## Check to make sure we are running as root
	if [[ ${EUID} -ne 0 ]]; then
		print_status "ERROR: This script must be run as root!"
		print_status "Try running the command 'sudo bash' and then run this script again..."
		exit 1
	fi
}

create_random_password() {
	# shellcheck disable=SC2005
	echo "$(< /dev/urandom tr -dc A-Za-z0-9 | head -c20)"
}

generate_passwords() {
	print_status "Generating MySQL passwords..."
	NEW_MYSQL_ROOT_PASSWORD=$(create_random_password)
	MYSQL_SIMPLERISK_PASSWORD=$(create_random_password)
	echo "MYSQL ROOT PASSWORD: ${NEW_MYSQL_ROOT_PASSWORD}" >> /root/passwords.txt
	echo "MYSQL SIMPLERISK PASSWORD: ${MYSQL_SIMPLERISK_PASSWORD}" >> /root/passwords.txt
	chmod 600 /root/passwords.txt
}

set_up_simplerisk() {
	print_status "Downloading the latest SimpleRisk release to /var/www/simplerisk..."
	if [ ! -d /var/www ]; then
		exec_cmd "mkdir -p /var/www/"
	elif [ -d /var/www/html ]; then
		exec_cmd "rm -r /var/www/html"
	fi
	exec_cmd "cd /var/www && wget https://github.com/simplerisk/bundles/raw/master/simplerisk-${CURRENT_SIMPLERISK_VERSION}.tgz"
	exec_cmd "cd /var/www && tar xvzf simplerisk-${CURRENT_SIMPLERISK_VERSION}.tgz"
	exec_cmd "rm -f /var/www/simplerisk-${CURRENT_SIMPLERISK_VERSION}.tgz"
	exec_cmd "cd /var/www/simplerisk && wget https://github.com/simplerisk/database/raw/master/simplerisk-en-${CURRENT_SIMPLERISK_VERSION}.sql -O database.sql"
	exec_cmd "chown -R ${1}: /var/www/simplerisk"
}

set_up_backup_cronjob() {
	exec_cmd "(crontab -l 2>/dev/null; echo \"* * * * * $(which php) -f /var/www/simplerisk/cron/cron.php\") | crontab -"
}

get_simplerisk_version() {
	# Get the current SimpleRisk release version
        CURRENT_SIMPLERISK_VERSION=$(curl -sL https://updates.simplerisk.com/Current_Version.xml | grep -oP '<appversion>(.*)</appversion>' | cut -d '>' -f 2 | cut -d '<' -f 1)
}

# shellcheck disable=SC2120
setup_ubuntu_debian(){
	get_simplerisk_version

	print_status "Running SimpleRisk ${CURRENT_SIMPLERISK_VERSION} installer..."

	print_status "Populating apt-get cache..."
	exec_cmd 'apt-get update'

	print_status "Waiting for the cache to be unlocked... (Needed for AWS)"
	exec_cmd 'while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do sleep 1; done;'

	print_status "Updating current packages (this may take a bit)..."
	exec_cmd "apt-get dist-upgrade -qq --assume-yes"

	if [ "${OS}" = "Ubuntu" ]; then
		print_status "Installing lamp-server..."
		exec_cmd "apt-get install -y lamp-server^"
	else
		print_status "Installing Apache..."
		exec_cmd "apt-get install -y apache2"

		print_status "Installing MariaDB..."
		exec_cmd "apt-get install -y mariadb-server"

		print_status "Installing PHP..."
		exec_cmd "apt-get install -y php php-mysql libapache2-mod-php"
	fi

	print_status "Installing mbstring module for PHP..."
	exec_cmd "apt-get install -y php-mbstring"

	print_status "Installing PHP development libraries..."
	exec_cmd "apt-get install -y php-dev"

	print_status "Installing ldap module for PHP..."
	exec_cmd "apt-get install -y php-ldap"

	print_status "Enabling the ldap module in PHP..."
	exec_cmd "phpenmod ldap"

	print_status "Installing curl module for PHP..."
	exec_cmd "apt-get install -y php-curl"

	print_status "Installing the gd module for PHP..."
	exec_cmd "apt-get install -y php-gd"

	print_status "Installing the zip module for PHP..."
	exec_cmd "apt-get install -y php-zip"

	print_status "Installing postfix..."
	exec_cmd "export DEBIAN_FRONTEND=noninteractive && apt-get install -y postfix mailutils"

	print_status "Enabling SSL for Apache..."
	exec_cmd "a2enmod rewrite"
	exec_cmd "a2enmod ssl"
	exec_cmd "a2ensite default-ssl"

	print_status "Configuring secure settings for Apache..."
	exec_cmd "sed -i 's/SSLProtocol all -SSLv3/SSLProtocol TLSv1.2/g' /etc/apache2/mods-enabled/ssl.conf"
	exec_cmd "sed -i 's/#SSLHonorCipherOrder on/SSLHonorCipherOrder on/g' /etc/apache2/mods-enabled/ssl.conf"
	exec_cmd "sed -i 's/ServerTokens OS/ServerTokens Prod/g' /etc/apache2/conf-enabled/security.conf"
	exec_cmd "sed -i 's/ServerSignature On/ServerSignature Off/g' /etc/apache2/conf-enabled/security.conf"

	print_status "Setting the maximum file upload size in PHP to 5MB and memory limit to 256M..."

	local php_version
	php_version="$(php -v | grep -E '^PHP [[:digit:]]' | cut -d '.' -f 1 | cut -d ' ' -f 2).*"
	exec_cmd "sed -i 's/\(upload_max_filesize =\) .*\(M\)/\1 5\2/g' /etc/php/$php_version/apache2/php.ini"
	exec_cmd "sed -i 's/\(memory_limit =\) .*\(M\)/\1 256\2/g' /etc/php/$php_version/apache2/php.ini"
	
	print_status "Setting the maximum input variables in PHP to 3000..."
	exec_cmd "sed -i '/max_input_vars = 1000/a max_input_vars = 3000' /etc/php/$php_version/apache2/php.ini"

	set_up_simplerisk "www-data"

	print_status "Configuring Apache..."
	exec_cmd "sed -i 's/\/var\/www\/html/\/var\/www\/simplerisk/g' /etc/apache2/sites-enabled/000-default.conf"
	# shellcheck disable=SC2143
	if [ ! "$(grep -q "RewriteEngine On" /etc/apache2/sites-enabled/000-default.conf)" ]; then
		exec_cmd "sed -i '/^<\/VirtualHost>/i \\\tRewriteEngine On\n\tRewriteCond %{HTTPS} !=on\n\tRewriteRule ^/?(.*) https://%{SERVER_NAME}/$1 [R,L]' /etc/apache2/sites-enabled/000-default.conf"
	fi
	exec_cmd "sed -i 's/\/var\/www\/html/\/var\/www\/simplerisk/g' /etc/apache2/sites-enabled/default-ssl.conf"
	# shellcheck disable=SC2143
	if [ ! "$(grep -q "AllowOverride all" /etc/apache2/sites-enabled/default-ssl.conf)" ]; then
		exec_cmd "sed -i '/<\/Directory>/a \\\t\t<Directory \"\/var\/www\/simplerisk\">\n\t\t\tAllowOverride all\n\t\t\tallow from all\n\t\t\tOptions -Indexes\n\t\t<\/Directory>' /etc/apache2/sites-enabled/default-ssl.conf"
	fi

	print_status "Configuring postfix..."
	exec_cmd "cp /usr/share/postfix/main.cf.debian /etc/postfix/main.cf"
	if [ ! -e "/var/spool/postfix/public/pickup" ]; then
		exec_cmd "mkfifo /var/spool/postfix/public/pickup"
	fi
	exec_cmd "service postfix restart"

	print_status "Restarting Apache to load the new configuration..."
	exec_cmd "service apache2 restart"

	generate_passwords

	local db
	[ "${OS}" = "Ubuntu" ] && db="MySQL" || db="MariaDB"
	print_status "Configuring $db..."
	if [ "${db}" = "MariaDB" ]; then
		cat << EOF >> /etc/mysql/my.cnf
[mysqld]
sql_mode=ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION
EOF
	else
		exec_cmd "sed -i '$ a sql-mode=\"NO_ENGINE_SUBSTITUTION\"' /etc/mysql/mysql.conf.d/mysqld.cnf"
	fi

	exec_cmd "mysql -uroot mysql -e \"CREATE DATABASE simplerisk\""
	exec_cmd "mysql -uroot simplerisk -e \"\\. /var/www/simplerisk/database.sql\""

	if [ "${OS}" = "Ubuntu " ] && [ "${VER}" = "18.04" ]; then
		exec_cmd "mysql -uroot simplerisk -e \"GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, ALTER, REFERENCES, INDEX ON simplerisk.* TO 'simplerisk'@'localhost' IDENTIFIED BY '${MYSQL_SIMPLERISK_PASSWORD}'\""
	else
	exec_cmd "mysql -uroot simplerisk -e \"CREATE USER 'simplerisk'@'localhost' IDENTIFIED BY '${MYSQL_SIMPLERISK_PASSWORD}'\""
	exec_cmd "mysql -uroot simplerisk -e \"GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, ALTER, REFERENCES, INDEX ON simplerisk.* TO 'simplerisk'@'localhost'\""
fi

	exec_cmd "mysql -uroot simplerisk -e \"UPDATE mysql.db SET References_priv='Y',Index_priv='Y' WHERE db='simplerisk';\""
	if [ "${OS}" = "Ubuntu" ]; then
		exec_cmd "mysql -uroot mysql -e \"ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${NEW_MYSQL_ROOT_PASSWORD}'\""
	else
		exec_cmd "mysql -uroot mysql -e \"ALTER USER 'root'@'localhost' IDENTIFIED BY '${NEW_MYSQL_ROOT_PASSWORD}'\""
	fi

	print_status "Setting the SimpleRisk database password..."
	exec_cmd "sed -i \"s/\(DB_PASSWORD', '\)simplerisk/\1${MYSQL_SIMPLERISK_PASSWORD}/\" /var/www/simplerisk/includes/config.php"
	exec_cmd "sed -i \"s/\(SIMPLERISK_INSTALLED', '\)false/\1true/\" /var/www/simplerisk/includes/config.php"

	print_status "Restarting $db to load the new configuration..."
	exec_cmd "service $(echo \"$db\" | awk '{print tolower($0)}') restart"

	print_status "Removing the SimpleRisk database file..."
	exec_cmd "rm -r /var/www/simplerisk/database.sql"

	print_status "Setting up Backup cronjob..."
	set_up_backup_cronjob

	if [ "${OS}" = "Debian GNU/Linux" ]; then
		print_status "Installing UFW firewall..."
		exec_cmd "apt-get install -y ufw"
	fi

	print_status "Enabling UFW firewall..."
	exec_cmd "ufw allow ssh"
	exec_cmd "ufw allow http"
	exec_cmd "ufw allow https"
	exec_cmd "ufw allow postfix"
	exec_cmd "ufw --force enable"

	print_status "Check /root/passwords.txt for the MySQL root and simplerisk passwords."
	print_status "INSTALLATION COMPLETED SUCCESSFULLY"
}

# shellcheck disable=SC2120
setup_centos_rhel(){
	get_simplerisk_version

	print_status "Running SimpleRisk ${CURRENT_SIMPLERISK_VERSION} installer..."

	print_status "Updating packages with yum.  This may take some time."
	exec_cmd "yum -y update"
	
	print_status "Installing the wget package..."
	exec_cmd "yum -y install wget"

	print_status "Installing Firewalld"
	exec_cmd "yum -y install firewalld"

	print_status "Installing the Apache web server..."
	exec_cmd "yum -y install httpd"

	print_status "Installing PHP for Apache..."
	if [ "${OS}" = "Red Hat Enterprise Linux" ] || [ "${OS}" = "Red Hat Enterprise Linux Server" ]; then
		if [[ "${VER}" = 8* ]]; then
			exec_cmd "yum -y install php php-mysqlnd php-mbstring php-opcache php-gd php-zip php-json php-ldap php-curl php-xml php-process"
		else
			exec_cmd "rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm"
			exec_cmd "rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-7.rpm"
			exec_cmd "yum -y --enablerepo=remi,remi-php74 install httpd php php-common"
			exec_cmd "yum -y --enablerepo=remi,remi-php74 install php-cli php-pdo php-mysqlnd php-gd php-zip php-mbstring php-xml php-curl php-ldap php-json"
		fi
	else
		exec_cmd "rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm"
		exec_cmd "rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-7.rpm"
		exec_cmd "yum -y --enablerepo=remi,remi-php74 install httpd php php-common"
		exec_cmd "yum -y --enablerepo=remi,remi-php74 install php-cli php-pdo php-mysqlnd php-gd php-zip php-mbstring php-xml php-curl php-ldap php-json"
	fi

	print_status "Setting the maximum file upload size in PHP to 5MB and memory limit to 256M..."
	exec_cmd "sed -i 's/\(upload_max_filesize =\) .*\(M\)/\1 5\2/g' /etc/php.ini"
	exec_cmd "sed -i 's/\(memory_limit =\) .*\(M\)/\1 256\2/g' /etc/php.ini"

	print_status "Setting the maximum input variables in PHP to 3000..."
	exec_cmd "sed -i '/max_input_vars = 1000/a max_input_vars = 3000' /etc/php.ini"

	print_status "Installing the MariaDB database server..."
	exec_cmd "curl -sL https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | bash -"
	if [[ "${VER}" = 7.9 ]]; then
		if [ "${OS}" = "Red Hat Enterprise Linux" ] || [ "${OS}" = "Red Hat Enterprise Linux Server" ]; then
			exec_cmd "yum -y install MariaDB-server"
		fi
	else
		if [ "${OS}" = "Red Hat Enterprise Linux" ] || [ "${OS}" = "Red Hat Enterprise Linux Server" ]; then
			exec_cmd "yum -y install perl-DBI libaio libsepol lsof boost-program-options libpmem galera-4"
			exec_cmd "yum -y install --repo=\"mariadb-main\" MariaDB-server"
		else
			exec_cmd "yum -y install MariaDB-server"
		fi
	fi

	print_status "Installing postfix..."
	exec_cmd "yum -y install postfix mailx"

	print_status "Enabling and starting the MariaDB database server..."
	exec_cmd "systemctl enable mariadb"
	exec_cmd "systemctl start mariadb"

	print_status "Installing mod_ssl"
	exec_cmd "yum -y install mod_ssl"

	set_up_simplerisk "apache"

	print_status "Configuring Apache..."
	if [ "${OS}" = "Red Hat Enterprise Linux" ] || [ "${OS}" = "Red Hat Enterprise Linux Server" ]; then
		exec_cmd "sed -i 's/#DocumentRoot \"\/var\/www\/html\"/DocumentRoot \"\/var\/www\/simplerisk\"/' /etc/httpd/conf.d/ssl.conf"
		exec_cmd "rm /etc/httpd/conf.d/welcome.conf"
	fi
	exec_cmd "mkdir /etc/httpd/sites-{available,enabled}"
	exec_cmd "sed -i 's/\(DocumentRoot \"\/var\/www\).*/\1\"/g' /etc/httpd/conf/httpd.conf"
	echo "IncludeOptional sites-enabled/*.conf" >> /etc/httpd/conf/httpd.conf
	cat << EOF > /etc/httpd/sites-enabled/simplerisk.conf
<VirtualHost *:80>
	DocumentRoot "/var/www/simplerisk/"
	ErrorLog /var/log/httpd/error_log
	CustomLog /var/log/httpd/access_log combined
	<Directory "/var/www/simplerisk/">
		AllowOverride all
		allow from all
		Options -Indexes
	</Directory>
	RewriteEngine On
	RewriteCond %{HTTPS} !=on
	RewriteRule ^/?(.*) https://%{SERVER_NAME}/$1 [R,L]
</VirtualHost>
EOF

	# shellcheck disable=SC2143
	if [ ! "$(grep -q "AllowOverride all" /etc/httpd/conf.d/ssl.conf)" ]; then
		exec_cmd "sed -i '/<\/Directory>/a \\\t\t<Directory \"\/var\/www\/simplerisk\">\n\t\t\tAllowOverride all\n\t\t\tallow from all\n\t\t\tOptions -Indexes\n\t\t<\/Directory>' /etc/httpd/conf.d/ssl.conf"
	fi
	if [ "${OS}" = "CentOS Linux" ]; then
		exec_cmd "sed -i '/<VirtualHost _default_:443>/a \\\t\tDocumentRoot \"/var/www/simplerisk\"' /etc/httpd/conf.d/ssl.conf"
	else
		exec_cmd "sed -i 's/#\(LoadModule mpm_prefork\)/\1/g' /etc/httpd/conf.modules.d/00-mpm.conf"
		exec_cmd "sed -i 's/\(LoadModule mpm_event\)/#\1/g' /etc/httpd/conf.modules.d/00-mpm.conf"
	fi

	generate_passwords

	print_status "Configuring MySQL..."
	exec_cmd "mysql -uroot mysql -e \"CREATE DATABASE simplerisk\""
	exec_cmd "mysql -uroot simplerisk -e \"\\. /var/www/simplerisk/database.sql\""
	exec_cmd "mysql -uroot simplerisk -e \"CREATE USER 'simplerisk'@'localhost' IDENTIFIED BY '${MYSQL_SIMPLERISK_PASSWORD}'\""
	exec_cmd "mysql -uroot simplerisk -e \"GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, ALTER ON simplerisk.* TO 'simplerisk'@'localhost'\""
	exec_cmd "mysql -uroot simplerisk -e \"UPDATE mysql.db SET References_priv='Y',Index_priv='Y' WHERE db='simplerisk';\""
	if [ "${OS}" = "CentOS Linux" ]; then
		exec_cmd "mysql -uroot mysql -e \"DROP DATABASE test\""
		exec_cmd "mysql -uroot mysql -e \"DROP USER ''@'localhost'\""
		exec_cmd "mysql -uroot mysql -e \"DROP USER ''@'$(hostname)'\""
	fi
	exec_cmd "mysql -uroot mysql -e \"ALTER USER 'root'@'localhost' IDENTIFIED BY '${NEW_MYSQL_ROOT_PASSWORD}'\""

	print_status "Setting the SimpleRisk database password..."
	exec_cmd "sed -i \"s/\(DB_PASSWORD', '\)simplerisk/\1${MYSQL_SIMPLERISK_PASSWORD}/\" /var/www/simplerisk/includes/config.php"
	exec_cmd "sed -i \"s/\(SIMPLERISK_INSTALLED', '\)false/\1true/\" /var/www/simplerisk/includes/config.php"
	cat << EOF >> /etc/my.cnf
[mysqld]
sql_mode=ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION
EOF

	print_status "Restarting MySQL to load the new configuration..."
	exec_cmd "systemctl restart mariadb"

	print_status "Removing the SimpleRisk database file..."
	exec_cmd "rm -r /var/www/simplerisk/database.sql"

	print_status "Setting up Backup cronjob..."
	set_up_backup_cronjob

	print_status "Configuring postfix"
	if [ ! -e "/var/spool/postfix/public/pickup" ]; then
		exec_cmd "mkfifo /var/spool/postfix/public/pickup"
	fi
	exec_cmd "systemctl restart postfix"

	print_status "Enabling and starting the Apache web server..."
	exec_cmd "systemctl enable httpd"
	exec_cmd "systemctl start httpd"

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
	exec_cmd "chcon -R -t httpd_sys_rw_content_t /var/www/simplerisk"

	print_status "Check /root/passwords.txt for the MySQL root and simplerisk passwords."
	print_status "INSTALLATION COMPLETED SUCCESSFULLY"
}

# shellcheck disable=SC2120
setup_suse(){
	get_simplerisk_version

	print_status "Running SimpleRisk ${CURRENT_SIMPLERISK_VERSION} installer..."

	print_status "Populating zypper cache..."
	exec_cmd 'zypper -n update'

	if [[ "${VER}" = 12* ]]; then
		print_status "Adding PHP 7.3 repository for SLES 12..."
		SP_VER="${VER: -1}"
		exec_cmd "yes | zypper -n addrepo -f https://download.opensuse.org/repositories/devel:/languages:/php:/php73/SLE_12_SP${SP_VER}/devel:languages:php:php73.repo"
		exec_cmd "zypper --gpg-auto-import-keys refresh"
	fi

	print_status "Installing Apache..."
	exec_cmd "zypper -n install apache2"

	print_status "Enabling Apache on reboot..."
	exec_cmd "systemctl enable apache2"

	print_status "Starting Apache..."
	exec_cmd "systemctl start apache2"

	print_status "Installing MariaDB..."
	exec_cmd "zypper -n install mariadb mariadb-client mariadb-tools"

	print_status "Enabling MySQL on reboot..."
	exec_cmd "systemctl enable mysql"

	print_status "Starting MySQL..."
	exec_cmd "systemctl start mysql"

	print_status "Installing PHP 7..."
	exec_cmd "zypper -n install php7 php7-mysql apache2-mod_php7 php7-ldap php7-curl php7-zlib php7-phar php7-mbstring php-posix php-gd php-zip"
	exec_cmd "a2enmod php7"

	print_status "Installing Postfix..."
	exec_cmd "zypper -n install postfix mailx"

	print_status "Enabling SSL for Apache..."
	exec_cmd "a2enmod rewrite"
	exec_cmd "a2enmod ssl"
	exec_cmd "a2enmod mod_ssl"
	
	print_status "Enabling Rewrite Module for Apache..."
	echo "LoadModule rewrite_module         /usr/lib64/apache2-prefork/mod_rewrite.so" >> /etc/apache2/loadmodule.conf

	print_status "Setting up SimpleRisk Virtual Host and SSL Self-Signed Cert"
	echo "Listen 443" >> /etc/apache2/vhosts.d/simplerisk.conf
	cat << EOF >> /etc/apache2/vhosts.d/simplerisk.conf
<VirtualHost *:80>
	DocumentRoot "/var/www/simplerisk/"
	ErrorLog /var/log/apache2/error_log
	CustomLog /var/log/apache2/access_log combined
	<Directory "/var/www/simplerisk/">
		AllowOverride all
		Require all granted
		Options -Indexes
		Options FollowSymLinks
		Options SymLinksIfOwnerMatch
	</Directory>
	RewriteEngine On
	RewriteCond %{HTTPS} !=on
	RewriteRule ^/?(.*) https://%{SERVER_NAME}/$1 [R,L]
</VirtualHost>
EOF
	
	# Generate the OpenSSL private key
	exec_cmd "openssl genrsa -des3 -passout pass:/passwords/pass_openssl.txt -out /etc/apache2/ssl.key/simplerisk.pass.key"
	exec_cmd "openssl rsa -passin pass:/passwords/pass_openssl.txt -in /etc/apache2/ssl.key/simplerisk.pass.key -out /etc/apache2/ssl.key/simplerisk.key"

	# Remove the original key file
	exec_cmd "rm /etc/apache2/ssl.key/simplerisk.pass.key"

	# Generate the CSR
	exec_cmd "openssl req -new -key /etc/apache2/ssl.key/simplerisk.key -out  /etc/apache2/ssl.csr/simplerisk.csr -subj \"/CN=simplerisk\""

	# Create the Certificate
	exec_cmd "openssl x509 -req -days 365 -in /etc/apache2/ssl.csr/simplerisk.csr -signkey /etc/apache2/ssl.key/simplerisk.key -out /etc/apache2/ssl.crt/simplerisk.crt"

	cat << EOF >> /etc/apache2/vhosts.d/ssl.conf
<VirtualHost *:443>
	DocumentRoot "/var/www/simplerisk/"
	ErrorLog /var/log/apache2/error_log
	CustomLog /var/log/apache2/access_log combined
	<Directory "/var/www/simplerisk/">
		AllowOverride all
		Require all granted
		Options -Indexes
		Options FollowSymLinks
		Options SymLinksIfOwnerMatch
	</Directory>
	SSLEngine on
	SSLCertificateFile /etc/apache2/ssl.crt/simplerisk.crt
	SSLCertificateKeyFile /etc/apache2/ssl.key/simplerisk.key
	#SSLCertificateChainFile /etc/apache2/ssl.crt/vhost-example-chain.crt
</VirtualHost>
EOF

	print_status "Configuring secure settings for Apache..."
	exec_cmd "sed -i 's/\(SSLProtocol\).*/\1 TLSv1.2/g' /etc/apache2/ssl-global.conf"
	exec_cmd "sed -i 's/#\(SSLHonorCipherOrder\)/\1/g' /etc/apache2/ssl-global.conf"
	#exec_cmd "sed -i 's/ServerTokens OS/ServerTokens Prod/g' /etc/apache2/conf-enabled/security.conf"
	#exec_cmd "sed -i 's/ServerSignature On/ServerSignature Off/g' /etc/apache2/conf-enabled/security.conf"

	print_status "Setting the maximum file upload size in PHP to 5MB and memory limit to 256M..."
	exec_cmd "sed -i 's/\(upload_max_filesize =\) .*\(M\)/\1 5\2/g' /etc/php7/apache2/php.ini"
	exec_cmd "sed -i 's/\(memory_limit =\) .*\(M\)/\1 256\2/g' /etc/php7/apache2/php.ini"

	print_status "Setting the maximum input variables in PHP to 3000..."
	exec_cmd "sed -i '/max_input_vars = 1000/a max_input_vars = 3000' /etc/php7/apache2/php.ini"

	set_up_simplerisk "wwwrun"

	print_status "Configuring Postfix..."
	if [ ! -e "/var/spool/postfix/public/pickup" ]; then
		exec_cmd "mkfifo /var/spool/postfix/public/pickup"
	fi
	exec_cmd "systemctl restart postfix"

	print_status "Restarting Apache to load the new configuration..."
	exec_cmd "systemctl restart apache2"

	generate_passwords

	print_status "Configuring MySQL..."
	if [[ "${VER}" = 15* ]]; then
		exec_cmd "sed -i 's/\(\[mysqld\]\)/\1\nsql_mode=NO_ENGINE_SUBSTITUTION/g' /etc/my.cnf"
	fi
	exec_cmd "sed -i '$ a sql-mode=\"NO_ENGINE_SUBSTITUTION\"' /etc/my.cnf"
	exec_cmd "sed -i 's/,STRICT_TRANS_TABLES//g' /etc/my.cnf"
	exec_cmd "mysql -uroot mysql -e \"CREATE DATABASE simplerisk\""
	exec_cmd "mysql -uroot simplerisk -e \"\\. /var/www/simplerisk/database.sql\""
	exec_cmd "mysql -uroot mysql -e \"CREATE USER 'simplerisk'@'localhost' IDENTIFIED BY '${MYSQL_SIMPLERISK_PASSWORD}'\""
	exec_cmd "mysql -uroot simplerisk -e \"GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, REFERENCES, INDEX, ALTER ON simplerisk.* TO 'simplerisk'@'localhost'\""
	exec_cmd "mysql -uroot mysql -e \"ALTER USER 'root'@'localhost' IDENTIFIED BY '${NEW_MYSQL_ROOT_PASSWORD}'\""
	
	print_status "Setting the SimpleRisk database password..."
	exec_cmd "sed -i \"s/\(DB_PASSWORD', '\)simplerisk/\1${MYSQL_SIMPLERISK_PASSWORD}/\" /var/www/simplerisk/includes/config.php"
	exec_cmd "sed -i \"s/\(SIMPLERISK_INSTALLED', '\)false/\1true/\" /var/www/simplerisk/includes/config.php"

	print_status "Restarting MySQL to load the new configuration..."
	exec_cmd "systemctl restart mysql"

	print_status "Removing the SimpleRisk database file..."
	exec_cmd "rm -r /var/www/simplerisk/database.sql"

	print_status "Setting up Backup cronjob..."
	set_up_backup_cronjob

	print_status "Check /root/passwords.txt for the MySQL root and simplerisk passwords."
	print_status "INSTALLATION COMPLETED SUCCESSFULLY"
}

detected_os_proceed(){
	echo "Detected that we are running ${OS} ${VER}. Continuing with SimpleRisk setup." 
}

detected_os_but_unsupported_version(){
	echo "Detected that we are running ${OS} ${VER}, but this version is not currently supported." && exit 1
}

validate_os(){
	case "${OS}" in
		"Ubuntu")
			if [[ "${VER}" = "18.04" ]] || [[ "${VER}" = "20.04" ]] || [[ "${VER}" = 22.* ]]; then
				detected_os_proceed && setup_ubuntu_debian && exit 0
			fi
			detected_os_but_unsupported_version;;
		"CentOS Linux")
			if [ "${VER}" = "8" ] || [ "${VER}" = "7" ]; then
				detected_os_proceed && setup_centos_rhel && exit 0
			fi
			detected_os_but_unsupported_version;;
		"SLES")
			if [[ "${VER}" = 12* ]] || [[ "${VER}" = 15* ]]; then
				detected_os_proceed && setup_suse && exit 0
			fi
			detected_os_but_unsupported_version;;
		"Red Hat Enterprise Linux"|"Red Hat Enterprise Linux Server")
			if [[ "${VER}" = 7.9 ]] || [[ "${VER}" = 8* ]]; then
				detected_os_proceed && setup_centos_rhel && exit 0
			fi
			detected_os_but_unsupported_version;;
		"Debian GNU/Linux")
			if [ "${VER}" = "11" ]; then
				detected_os_proceed && setup_ubuntu_debian && exit 0
			fi
			detected_os_but_unsupported_version;;
		*)
			echo "The SimpleRisk setup script cannot reliably determine which commands to run for this OS. Exiting." && exit 1;;
	esac
}

os_detect(){
	if [ -f /etc/os-release ]; then
		# freedesktop.org and systemd
		# shellcheck source=/dev/null
		. /etc/os-release
		OS=$NAME
		VER=$VERSION_ID
	elif type lsb_release >/dev/null 2>&1; then
		# linuxbase.org
		OS=$(lsb_release -si)
		VER=$(lsb_release -sr)
	elif [ -f /etc/lsb-release ]; then
		# For some versions of Debian/Ubuntu without lsb_release command
		# shellcheck source=/dev/null
		. /etc/lsb-release
		OS=$DISTRIB_ID
		VER=$DISTRIB_RELEASE
	elif [ -f /etc/debian_version ]; then
		# Older Debian/Ubuntu/etc.
		OS=Debian
		VER=$(cat /etc/debian_version)
	elif [ -f /etc/SuSe-release ] || [ -f /etc/redhat-release ]; then
		# Older SuSE/etc. or Red Hat, CentOS, etc.
		echo "The SimpleRisk setup script cannot reliably determine which commands to run for this OS. Exiting."
		exit 1
	else
		# Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
		OS=$(uname -s)
		VER=$(uname -r)
	fi

	validate_os
}

ask_user(){
	read -r -p "This script will install SimpleRisk on this system.  Are you sure that you would like to proceed? [ Yes / No ]: " answer < /dev/tty
	case "${answer}" in
		Yes|yes|Y|y ) os_detect;;
		* ) exit 1;;
	esac
}

validate_args(){
	while [[ $# -gt 0 ]]
	do
		key="${1}"
		case "${key}" in
			-n|--no-assistance)
				HEADLESS=y 
				shift;;
			-d|--debug)
				DEBUG=y
				shift;;
			*)    # unknown option
				echo "Provided parameter ${key} is not valid. Stopping."
				exit 1;;
		esac
	done

	if [ -n "${HEADLESS}" ]; then
		os_detect
	else
		ask_user
	fi
}

setup(){
	# Check to make sure we are running as root
	check_root
	# Ask user on how to proceed
	validate_args "${@:1}"
}

## Defer setup until we have the complete script
setup "${@:1}"
