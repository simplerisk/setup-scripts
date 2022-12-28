#!/usr/bin/env bash

###########################################
# SIMPLERISK SETUP SCRIPT
# Currently works for:
# - Ubuntu 18.04, 20.04, 22.04 and 22.10
# - Debian 11
# - CentOS 7
# - Red Hat Enterprise Linux (RHEL) 8, 9
# - SUSE Linux Enterprise Server (SLES) 15
#
# Run as root or insert `sudo -E` before `bash`: 
# curl -sL https://raw.githubusercontent.com/simplerisk/setup-scripts/master/simplerisk-setup.sh | bash -
# OR
# wget -qO- https://raw.githubusercontent.com/simplerisk/setup-scripts/master/simplerisk-setup.sh | bash -
###########################################
set -eo pipefail
export DEBIAN_FRONTEND=noninteractive
MYSQL_KEY_URL='http://repo.mysql.com/RPM-GPG-KEY-mysql-2022'

#########################
## MAIN FLOW FUNCTIONS ##
#########################
setup(){
	# Check to make sure we are running as root
	check_root
	# Ask user on how to proceed
	validate_args "${@:1}"
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
			-h|--help)
				print_help
				exit 0;;
			*)    # unknown option
				echo "Provided parameter ${key} is not valid."
				print_help
				exit 1;;
		esac
	done

	if [ -n "${HEADLESS}" ]; then
		os_detect
	else
		ask_user
	fi
}

ask_user(){
	read -r -p 'This script will install SimpleRisk on this system.  Are you sure that you would like to proceed? [ Yes / No ]: ' answer < /dev/tty
	case "${answer}" in
		Yes|yes|Y|y ) os_detect;;
		* ) exit 1;;
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
		OS='Debian GNU/Linux'
		VER=$(cat /etc/debian_version)
	elif [ -f /etc/SuSe-release ] || [ -f /etc/redhat-release ]; then
		# Older SuSE/etc. or Red Hat, CentOS, etc.
		echo 'The SimpleRisk setup script cannot reliably determine which commands to run for this OS. Exiting.'
		exit 1
	else
		# Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
		OS=$(uname -s)
		VER=$(uname -r)
	fi

	validate_os
}

validate_os(){
	case "${OS}" in
		'Ubuntu')
			if [[ "${VER}" = "18.04" ]] || [[ "${VER}" = "20.04" ]] || [[ "${VER}" = 22.* ]]; then
				detected_os_proceed && setup_ubuntu_debian && success_final_message && exit 0
			fi
			detected_os_but_unsupported_version;;
		'Debian GNU/Linux')
			if [ "${VER}" = "11" ]; then
				detected_os_proceed && setup_ubuntu_debian && success_final_message && exit 0
			fi
			detected_os_but_unsupported_version;;
		'CentOS Linux')
			if [ "${VER}" = "7" ]; then
				detected_os_proceed && setup_centos_rhel && success_final_message && exit 0
			fi
			detected_os_but_unsupported_version;;
		'Red Hat Enterprise Linux'|'Red Hat Enterprise Linux Server')
			if [[ "${VER}" = 8* ]] || [[ "${VER}" = 9* ]]; then
				detected_os_proceed && setup_centos_rhel && success_final_message && exit 0
			fi
			detected_os_but_unsupported_version;;
		'SLES')
			if [[ "${VER}" = 15* ]]; then
				detected_os_proceed
				if [ -z "${HEADLESS:-}" ]; then
					read -r -p 'Before continuing, SLES 15 does not have sendmail available on its repositories. You will need to configure postfix to be able to send emails. Do you still want to proceed? [ Yes / No ]: ' answer < /dev/tty
					case "${answer}" in
						Yes|yes|Y|y ) setup_suse && exit 0;;
						* ) exit 1;;
					esac
				else
					setup_suse && success_final_message && exit 0;
				fi
			fi
			detected_os_but_unsupported_version;;
		*)
			echo 'The SimpleRisk setup script cannot reliably determine which commands to run for this OS. Exiting.' && exit 1;;
	esac
}

#########################
## AUXILIARY FUNCTIONS ##
#########################
check_root() {
	## Check to make sure we are running as root
	if [ ${EUID} -ne 0 ]; then
		print_status 'ERROR: This script must be run as root!'
		print_status "Try running the command 'sudo bash' and then run this script again..."
		exit 1
	fi
}

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
	[ -v DEBUG ] || NO_LOG='> /dev/null 2>&1'
	echo "+ ${1} ${NO_LOG:-}"
	bash -c "${1} ${NO_LOG:-}"
}

create_random_password() {
	local char_pattern
	char_pattern='A-Za-z0-9'
	if [ -n "$2" ]; then
		char_pattern=$char_pattern'!?^@%'
	fi
	< /dev/urandom tr -dc "${char_pattern}" | head -c"${1:-20}"
}

generate_passwords() {
	print_status 'Generating MySQL passwords...'
	NEW_MYSQL_ROOT_PASSWORD=$(create_random_password)
	MYSQL_SIMPLERISK_PASSWORD=$(create_random_password)
	echo "MYSQL ROOT PASSWORD: ${NEW_MYSQL_ROOT_PASSWORD}" >> /root/passwords.txt
	echo "MYSQL SIMPLERISK PASSWORD: ${MYSQL_SIMPLERISK_PASSWORD}" >> /root/passwords.txt
	chmod 600 /root/passwords.txt
}

set_up_database() {
	# $1 should receive the mysqld.log path to retrieve password:
	# CentOS 7, RHEL 9: /var/log/mysqld.log
	# SLES 15:  /var/log/mysql/mysqld.log
	local password_flag
	if [[ -n $1 ]]; then
		local initial_root_password
		local temp_password
		initial_root_password=$(grep Note "$1" | awk -F " " '{print $NF}')
		temp_password="$(create_random_password 100 y)"
		exec_cmd "mysql -u root mysql -e \"ALTER USER 'root'@'localhost' IDENTIFIED BY '${temp_password}'\" --password=\"${initial_root_password}\" --connect-expired-password"
		password_flag=" --password='${temp_password}'"
		exec_cmd "mysql -u root mysql -e \"SET GLOBAL validate_password.policy = LOW;\"$password_flag"
	fi
	exec_cmd "mysql -uroot mysql -e 'CREATE DATABASE simplerisk'${password_flag:-}"
	exec_cmd "mysql -uroot mysql -e \"CREATE USER 'simplerisk'@'localhost' IDENTIFIED BY '${MYSQL_SIMPLERISK_PASSWORD}'\"${password_flag:-}"
	exec_cmd "mysql -uroot simplerisk -e '\\. /var/www/simplerisk/database.sql'${password_flag:-}"
	exec_cmd "mysql -uroot simplerisk -e \"GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, REFERENCES, INDEX, ALTER ON simplerisk.* TO 'simplerisk'@'localhost'\"${password_flag:-}"
	exec_cmd "mysql -u root mysql -e \"ALTER USER 'root'@'localhost' IDENTIFIED BY '${NEW_MYSQL_ROOT_PASSWORD}'\"${password_flag:-}"
}

set_up_simplerisk() {
	print_status 'Downloading the latest SimpleRisk release to /var/www/simplerisk...'
	if [ ! -d /var/www ]; then
		exec_cmd 'mkdir -p /var/www/'
	elif [ -d /var/www/html ]; then
		exec_cmd 'rm -r /var/www/html'
	fi
	exec_cmd "cd /var/www && wget https://github.com/simplerisk/bundles/raw/master/simplerisk-${CURRENT_SIMPLERISK_VERSION}.tgz"
	exec_cmd "cd /var/www && tar xvzf simplerisk-${CURRENT_SIMPLERISK_VERSION}.tgz"
	exec_cmd "rm -f /var/www/simplerisk-${CURRENT_SIMPLERISK_VERSION}.tgz"
	exec_cmd "cd /var/www/simplerisk && wget https://github.com/simplerisk/database/raw/master/simplerisk-en-${CURRENT_SIMPLERISK_VERSION}.sql -O database.sql"
	exec_cmd "chown -R ${1}: /var/www/simplerisk"
}

set_up_backup_cronjob() {
	exec_cmd "(crontab -l 2>/dev/null; echo '* * * * * $(which php) -f /var/www/simplerisk/cron/cron.php') | crontab -"
}

get_simplerisk_version() {
	# Get the current SimpleRisk release version
        CURRENT_SIMPLERISK_VERSION=$(curl -sL https://updates.simplerisk.com/Current_Version.xml | grep -oP '<appversion>(.*)</appversion>' | cut -d '>' -f 2 | cut -d '<' -f 1)
}

#######################
## MESSAGE FUNCTIONS ##
#######################
detected_os_proceed(){
	echo "Detected that we are running ${OS} ${VER}. Continuing with SimpleRisk setup." 
}

detected_os_but_unsupported_version(){
	echo "Detected that we are running ${OS} ${VER}, but this version is not currently supported." && exit 1
}

success_final_message(){
	print_status 'Check /root/passwords.txt for the MySQL root and simplerisk passwords.'
	print_status 'INSTALLATION COMPLETED SUCCESSFULLY'
}

print_help() {
        cat << EOC

Script to set up SimpleRisk on a server.

./simplerisk-setup [-d|--debug] [-n|--no-assistance] [-h|--help]

Flags:
-d|--debug:            Shows the output of the commands being run by this script
-n|--no-assistance:    Runs the script in headless mode (will assume yes on anything)
-h|--help:             Shows instructions on how to use this script
EOC
}

########################
## OS SETUP FUNCTIONS ##
########################
# shellcheck disable=SC2120
setup_ubuntu_debian(){
	get_simplerisk_version

	print_status "Running SimpleRisk ${CURRENT_SIMPLERISK_VERSION} installer..."

	print_status 'Populating apt-get cache...'
	exec_cmd 'apt-get update'

	# Add PHP8 for Ubuntu 18/20|Debian 11
	if [ "${OS}" != 'Ubuntu' ] || [[ "${VER}" != 22.* ]]; then
		exec_cmd 'mkdir -p /etc/apt/keyrings'
		local apt_php_version
		apt_php_version=8.1
		if [ "${OS}" = 'Ubuntu' ]; then
			print_status "Adding Ondrej's PPA with PHP8"
			exec_cmd 'add-apt-repository -y ppa:ondrej/php'
		else
			print_status 'Install gnupg to handle keyrings...'
			exec_cmd 'apt-get install -y gnupg'

			print_status "Adding Ondrej's repository with PHP8"
			exec_cmd 'wget -qO - https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /etc/apt/keyrings/sury-php.gpg'
			exec_cmd "echo 'deb [signed-by=/etc/apt/keyrings/sury-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main' | sudo tee /etc/apt/sources.list.d/sury-php.list"
		fi

		# Add MySQL 8 for Ubuntu 18
		if [[ "${OS}" = 'Ubuntu' && "${VER}" = '18.04' ]] || [ "${OS}" = 'Debian GNU/Linux' ]; then
			print_status 'Adding MySQL 8 repository'
			exec_cmd "wget -qO - $MYSQL_KEY_URL | gpg --dearmor -o /etc/apt/keyrings/mysql.gpg"
			exec_cmd "echo 'deb [signed-by=/etc/apt/keyrings/mysql.gpg] http://repo.mysql.com/apt/$(lsb_release -si | tr '[:upper:]' '[:lower:]')/ $(lsb_release -sc) mysql-8.0' | sudo tee /etc/apt/sources.list.d/mysql.list"
		fi

		print_status 'Re-populating apt-get cache with added repos...'
		exec_cmd 'apt-get update'
	fi

	print_status 'Updating current packages (this may take a bit)...'
	exec_cmd 'apt-get dist-upgrade -qq --assume-yes'

	if [ "${OS}" = 'Ubuntu' ] && [[ "${VER}" = 22* ]]; then
		print_status 'Installing lamp-server...'
		exec_cmd 'apt-get install -y lamp-server^'
	else
		print_status 'Installing Apache...'
		exec_cmd 'apt-get install -y apache2'

		print_status 'Installing MySQL...'
		exec_cmd 'apt-get install -y mysql-server'

		print_status 'Installing PHP...'
		exec_cmd "apt-get install -y php${apt_php_version:-} php${apt_php_version:-}-mysql libapache2-mod-php${apt_php_version:-}"
	fi

	print_status 'Installing mbstring module for PHP...'
	exec_cmd "apt-get install -y php${apt_php_version:-}-mbstring"

	print_status 'Installing PHP development libraries...'
	exec_cmd "apt-get install -y php${apt_php_version:-}-dev"

	print_status 'Installing ldap module for PHP...'
	exec_cmd "apt-get install -y php${apt_php_version:-}-ldap"

	print_status 'Enabling the ldap module in PHP...'
	exec_cmd 'phpenmod ldap'

	print_status 'Installing curl module for PHP...'
	exec_cmd "apt-get install -y php${apt_php_version:-}-curl"

	print_status 'Installing the gd module for PHP...'
	exec_cmd "apt-get install -y php${apt_php_version:-}-gd"

	print_status 'Installing the zip module for PHP...'
	exec_cmd "apt-get install -y php${apt_php_version:-}-zip"

	print_status 'Installing the intl module for PHP...'
	exec_cmd "apt-get install -y php${apt_php_version:-}-intl"

	print_status 'Enabling SSL for Apache...'
	exec_cmd 'a2enmod rewrite'
	exec_cmd 'a2enmod ssl'
	exec_cmd 'a2ensite default-ssl'

	print_status 'Installing sendmail...'
	exec_cmd 'apt-get install -y sendmail'

	print_status 'Configuring secure settings for Apache...'
	exec_cmd "sed -i 's/SSLProtocol all -SSLv3/SSLProtocol TLSv1.2/g' /etc/apache2/mods-enabled/ssl.conf"
	exec_cmd "sed -i 's/#SSLHonorCipherOrder on/SSLHonorCipherOrder on/g' /etc/apache2/mods-enabled/ssl.conf"
	exec_cmd "sed -i 's/ServerTokens OS/ServerTokens Prod/g' /etc/apache2/conf-enabled/security.conf"
	exec_cmd "sed -i 's/ServerSignature On/ServerSignature Off/g' /etc/apache2/conf-enabled/security.conf"

	print_status 'Setting the maximum file upload size in PHP to 5MB and memory limit to 256M...'

	local php_version
	php_version="$(php -v | grep -E '^PHP [[:digit:]]' | cut -d '.' -f 1 | cut -d ' ' -f 2).*"
	exec_cmd "sed -i 's/\(upload_max_filesize =\) .*\(M\)/\1 5\2/g' /etc/php/$php_version/apache2/php.ini"
	exec_cmd "sed -i 's/\(memory_limit =\) .*\(M\)/\1 256\2/g' /etc/php/$php_version/apache2/php.ini"
	
	print_status 'Setting the maximum input variables in PHP to 3000...'
	exec_cmd "sed -i '/max_input_vars = 1000/a max_input_vars = 3000' /etc/php/$php_version/apache2/php.ini"

	set_up_simplerisk 'www-data'

	print_status 'Configuring Apache...'
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

	print_status 'Configuring Sendmail...'
	exec_cmd "sed -i 's/\(localhost\)/\1 $(hostname)/g' /etc/hosts"
	exec_cmd 'yes | sendmailconfig'
	exec_cmd 'service sendmail start'

	print_status 'Restarting Apache to load the new configuration...'
	exec_cmd 'service apache2 restart'

	generate_passwords

	print_status 'Configuring MySQL...'
	exec_cmd "sed -i '$ a sql-mode=\"NO_ENGINE_SUBSTITUTION\"' /etc/mysql/mysql.conf.d/mysqld.cnf"
	set_up_database

	print_status 'Setting the SimpleRisk database password...'
	exec_cmd "sed -i \"s/\(DB_PASSWORD', '\)simplerisk/\1${MYSQL_SIMPLERISK_PASSWORD}/\" /var/www/simplerisk/includes/config.php"
	exec_cmd "sed -i \"s/\(SIMPLERISK_INSTALLED', '\)false/\1true/\" /var/www/simplerisk/includes/config.php"

	print_status 'Restarting MySQL to load the new configuration...'
	exec_cmd 'service mysql restart'

	print_status 'Removing the SimpleRisk database file...'
	exec_cmd 'rm -r /var/www/simplerisk/database.sql'

	print_status 'Setting up Backup cronjob...'
	set_up_backup_cronjob

	if [ "${OS}" = 'Debian GNU/Linux' ]; then
		print_status 'Installing UFW firewall...'
		exec_cmd 'apt-get install -y ufw'
	fi

	print_status 'Enabling UFW firewall...'
	exec_cmd 'ufw allow ssh'
	exec_cmd 'ufw allow http'
	exec_cmd 'ufw allow https'
	exec_cmd 'ufw --force enable'
}

# shellcheck disable=SC2120
setup_centos_rhel(){

	[ "${OS}" = 'CentOS Linux' ] && pkg_manager='yum' || pkg_manager='dnf'

	get_simplerisk_version

	print_status "Running SimpleRisk ${CURRENT_SIMPLERISK_VERSION} installer..."

	print_status "Updating packages with $pkg_manager. This may take some time."
	exec_cmd "$pkg_manager -y update"
	
	print_status 'Installing the wget package...'
	exec_cmd "$pkg_manager -y install wget"

	print_status 'Installing Firewalld...'
	exec_cmd "$pkg_manager -y install firewalld"

	print_status 'Enabling MySQL 8 repositories...'
	exec_cmd "rpm --import ${MYSQL_KEY_URL}"
	case ${VER:0:1} in
		7) exec_cmd 'rpm -Uvh https://dev.mysql.com/get/mysql80-community-release-el7-7.noarch.rpm';;
		8) exec_cmd 'rpm -Uvh https://dev.mysql.com/get/mysql80-community-release-el8-4.noarch.rpm';;
		9) exec_cmd 'rpm -Uvh https://dev.mysql.com/get/mysql80-community-release-el9-1.noarch.rpm';;
	esac

	print_status 'Enabling PHP 8 repositories...'
	exec_cmd "$pkg_manager -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-${VER:0:1}.noarch.rpm"
	local remi_key_url
	remi_key_url='https://rpms.remirepo.net/RPM-GPG-KEY-remi'
	case ${VER:0:1} in
		7) exec_cmd "rpm --import ${remi_key_url}";;
		8) exec_cmd "rpm --import ${remi_key_url}2018";;
		9) exec_cmd "rpm --import ${remi_key_url}2021";;
	esac
	exec_cmd "$pkg_manager -y install https://rpms.remirepo.net/enterprise/remi-release-${VER:0:1}.rpm"
	exec_cmd "$pkg_manager -y update"


	print_status 'Installing PHP for Apache...'
	if [ "${OS}" = 'CentOS Linux' ]; then
		exec_cmd "$pkg_manager -y --enablerepo=remi,remi-php81 install httpd php php-common"
		exec_cmd "$pkg_manager -y --enablerepo=remi,remi-php81 install php-cli php-pdo php-mysqlnd php-gd php-zip php-mbstring php-xml php-curl php-ldap php-json php-intl"
	else
		exec_cmd "$pkg_manager -y module reset php"
		exec_cmd "$pkg_manager -y module enable php:remi-8.1"
		exec_cmd "$pkg_manager -y install httpd php php-common php-mysqlnd php-mbstring php-opcache php-gd php-zip php-json php-ldap php-curl php-xml php-intl php-process"
	fi

	print_status 'Setting the maximum file upload size in PHP to 5MB and memory limit to 256M...'
	exec_cmd "sed -i 's/\(upload_max_filesize =\) .*\(M\)/\1 5\2/g' /etc/php.ini"
	exec_cmd "sed -i 's/\(memory_limit =\) .*\(M\)/\1 256\2/g' /etc/php.ini"

	print_status 'Setting the maximum input variables in PHP to 3000...'
	exec_cmd "sed -i '/max_input_vars = 1000/a max_input_vars = 3000' /etc/php.ini"

	print_status 'Installing the MySQL database server...'
	exec_cmd "$pkg_manager install -y mysql-server"

	print_status 'Enabling and starting MySQL database server...'
	exec_cmd 'systemctl enable mysqld'
	exec_cmd 'systemctl start mysqld'

	print_status 'Installing mod_ssl'
	exec_cmd "$pkg_manager -y install mod_ssl"

	print_status 'Installing sendmail'
	exec_cmd "$pkg_manager -y install sendmail sendmail-cf m4"

	set_up_simplerisk 'apache'

	print_status 'Configuring Apache...'
	if [ "${OS}" = 'Red Hat Enterprise Linux' ] || [ "${OS}" = 'Red Hat Enterprise Linux Server' ]; then
		exec_cmd "sed -i 's/#DocumentRoot \"\/var\/www\/html\"/DocumentRoot \"\/var\/www\/simplerisk\"/' /etc/httpd/conf.d/ssl.conf"
		exec_cmd 'rm /etc/httpd/conf.d/welcome.conf'
	fi
	exec_cmd 'mkdir /etc/httpd/sites-{available,enabled}'
	exec_cmd "sed -i 's/\(DocumentRoot \"\/var\/www\).*/\1\"/g' /etc/httpd/conf/httpd.conf"
	echo 'IncludeOptional sites-enabled/*.conf' >> /etc/httpd/conf/httpd.conf
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
	if [ ! "$(grep -q 'AllowOverride all' /etc/httpd/conf.d/ssl.conf)" ]; then
		exec_cmd "sed -i '/<\/Directory>/a \\\t\t<Directory \"\/var\/www\/simplerisk\">\n\t\t\tAllowOverride all\n\t\t\tallow from all\n\t\t\tOptions -Indexes\n\t\t<\/Directory>' /etc/httpd/conf.d/ssl.conf"
	fi
	if [ "${OS}" = 'CentOS Linux' ]; then
		exec_cmd "sed -i '/<VirtualHost _default_:443>/a \\\t\tDocumentRoot \"/var/www/simplerisk\"' /etc/httpd/conf.d/ssl.conf"
	else
		exec_cmd "sed -i 's/#\(LoadModule mpm_prefork\)/\1/g' /etc/httpd/conf.modules.d/00-mpm.conf"
		exec_cmd "sed -i 's/\(LoadModule mpm_event\)/#\1/g' /etc/httpd/conf.modules.d/00-mpm.conf"
	fi

	generate_passwords

	print_status 'Configuring MySQL...'
	if [ "${OS}" = 'CentOS Linux' ]; then
		set_up_database	/var/log/mysqld.log
	else
		if [[ "${VER}" = 9* ]]; then
			set_up_database	/var/log/mysqld.log
		fi
	fi

	print_status 'Setting the SimpleRisk database password...'
	exec_cmd "sed -i \"s/\(DB_PASSWORD', '\)simplerisk/\1${MYSQL_SIMPLERISK_PASSWORD}/\" /var/www/simplerisk/includes/config.php"
	exec_cmd "sed -i \"s/\(SIMPLERISK_INSTALLED', '\)false/\1true/\" /var/www/simplerisk/includes/config.php"
	# WIP: Removing NO_AUTO_CREATE_USER
	cat << EOF >> /etc/my.cnf
[mysqld]
sql_mode=ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION
EOF

	print_status 'Restarting MySQL to load the new configuration...'
	exec_cmd 'systemctl restart mysqld'

	print_status 'Removing the SimpleRisk database file...'
	exec_cmd 'rm -r /var/www/simplerisk/database.sql'
	print_status 'Setting up Backup cronjob...'
	set_up_backup_cronjob

	print_status 'Enabling and starting the Apache web server...'
	exec_cmd 'systemctl enable httpd'
	exec_cmd 'systemctl start httpd'

	print_status 'Configuring and starting Sendmail...'
	exec_cmd "sed -i 's/\(localhost\)/\1 $(hostname)/g' /etc/hosts"
	exec_cmd 'systemctl start sendmail'

	print_status 'Opening Firewall for HTTP/HTTPS traffic'
	exec_cmd 'systemctl enable firewalld'
	exec_cmd 'systemctl start firewalld'
	for service in http https ssh; do
		exec_cmd "firewall-cmd --permanent --zone=public --add-service=${service}"
	done
	exec_cmd 'firewall-cmd --reload'

	print_status 'Configuring SELinux for SimpleRisk...'
	exec_cmd 'setsebool -P httpd_builtin_scripting=1'
	exec_cmd 'setsebool -P httpd_can_network_connect=1'
	exec_cmd 'setsebool -P httpd_can_sendmail=1'
	exec_cmd 'setsebool -P httpd_dbus_avahi=1'
	exec_cmd 'setsebool -P httpd_enable_cgi=1'
	exec_cmd 'setsebool -P httpd_read_user_content=1'
	exec_cmd 'setsebool -P httpd_tty_comm=1'
	exec_cmd 'setsebool -P allow_httpd_anon_write=0'
	exec_cmd 'setsebool -P allow_httpd_mod_auth_ntlm_winbind=0'
	exec_cmd 'setsebool -P allow_httpd_mod_auth_pam=0'
	exec_cmd 'setsebool -P allow_httpd_sys_script_anon_write=0'
	exec_cmd 'setsebool -P httpd_can_check_spam=0'
	exec_cmd 'setsebool -P httpd_can_network_connect_cobbler=0'
	exec_cmd 'setsebool -P httpd_can_network_connect_db=0'
	exec_cmd 'setsebool -P httpd_can_network_memcache=0'
	exec_cmd 'setsebool -P httpd_can_network_relay=0'
	exec_cmd 'setsebool -P httpd_dbus_sssd=0'
	exec_cmd 'setsebool -P httpd_enable_ftp_server=0'
	exec_cmd 'setsebool -P httpd_enable_homedirs=0'
	exec_cmd 'setsebool -P httpd_execmem=0'
	exec_cmd 'setsebool -P httpd_manage_ipa=0'
	exec_cmd 'setsebool -P httpd_run_preupgrade=0'
	exec_cmd 'setsebool -P httpd_run_stickshift=0'
	exec_cmd 'setsebool -P httpd_serve_cobbler_files=0'
	exec_cmd 'setsebool -P httpd_setrlimit=0'
	exec_cmd 'setsebool -P httpd_ssi_exec=0'
	exec_cmd 'setsebool -P httpd_tmp_exec=0'
	exec_cmd 'setsebool -P httpd_use_cifs=0'
	exec_cmd 'setsebool -P httpd_use_fusefs=0'
	exec_cmd 'setsebool -P httpd_use_gpg=0'
	exec_cmd 'setsebool -P httpd_use_nfs=0'
	exec_cmd 'setsebool -P httpd_use_openstack=0'
	exec_cmd 'setsebool -P httpd_verify_dns=0'
	exec_cmd 'chcon -R -t httpd_sys_rw_content_t /var/www/simplerisk'
}

# shellcheck disable=SC2120
setup_suse(){
	get_simplerisk_version

	print_status "Running SimpleRisk ${CURRENT_SIMPLERISK_VERSION} installer..."

	print_status 'Populating zypper cache...'
	exec_cmd 'zypper -n update'

	print_status 'Adding MySQL 8 repositories...'
	exec_cmd 'rpm -Uvh https://dev.mysql.com/get/mysql80-community-release-sl15-6.noarch.rpm'
	exec_cmd "rpm --import $MYSQL_KEY_URL"
	exec_cmd 'zypper -n ref'

	print_status 'Installing Apache...'
	exec_cmd 'zypper -n install apache2'

	print_status 'Enabling Apache on reboot...'
	exec_cmd 'systemctl enable apache2'

	print_status 'Starting Apache...'
	exec_cmd 'systemctl start apache2'

	print_status 'Installing MySQL 8...'
	exec_cmd 'zypper -n install mysql-community-server'

	print_status 'Enabling MySQL on reboot...'
	exec_cmd 'systemctl enable mysql'

	print_status 'Starting MySQL...'
	exec_cmd 'systemctl start mysql'

	print_status 'Installing PHP 8...'
	exec_cmd 'zypper -n install php8 php8-mysql apache2-mod_php8 php8-ldap php8-curl php8-zlib php8-phar php8-mbstring php8-intl php8-posix php8-gd php8-zip'
	exec_cmd 'a2enmod php8'

	print_status 'Enabling SSL for Apache...'
	exec_cmd 'a2enmod rewrite'
	exec_cmd 'a2enmod ssl'
	exec_cmd 'a2enmod mod_ssl'
	
	print_status 'Enabling Rewrite Module for Apache...'
	echo 'LoadModule rewrite_module         /usr/lib64/apache2-prefork/mod_rewrite.so' >> /etc/apache2/loadmodule.conf

	print_status 'Setting up SimpleRisk Virtual Host and SSL Self-Signed Cert'
	echo 'Listen 443' >> /etc/apache2/vhosts.d/simplerisk.conf
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
	exec_cmd 'openssl genrsa -des3 -passout pass:/passwords/pass_openssl.txt -out /etc/apache2/ssl.key/simplerisk.pass.key'
	exec_cmd 'openssl rsa -passin pass:/passwords/pass_openssl.txt -in /etc/apache2/ssl.key/simplerisk.pass.key -out /etc/apache2/ssl.key/simplerisk.key'

	# Remove the original key file
	exec_cmd 'rm /etc/apache2/ssl.key/simplerisk.pass.key'

	# Generate the CSR
	exec_cmd 'openssl req -new -key /etc/apache2/ssl.key/simplerisk.key -out  /etc/apache2/ssl.csr/simplerisk.csr -subj "/CN=simplerisk"'

	# Create the Certificate
	exec_cmd 'openssl x509 -req -days 365 -in /etc/apache2/ssl.csr/simplerisk.csr -signkey /etc/apache2/ssl.key/simplerisk.key -out /etc/apache2/ssl.crt/simplerisk.crt'

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

	print_status 'Configuring secure settings for Apache...'
	exec_cmd "sed -i 's/\(SSLProtocol\).*/\1 TLSv1.2/g' /etc/apache2/ssl-global.conf"
	exec_cmd "sed -i 's/#\(SSLHonorCipherOrder\)/\1/g' /etc/apache2/ssl-global.conf"
	#exec_cmd "sed -i 's/ServerTokens OS/ServerTokens Prod/g' /etc/apache2/conf-enabled/security.conf"
	#exec_cmd "sed -i 's/ServerSignature On/ServerSignature Off/g' /etc/apache2/conf-enabled/security.conf"

	print_status 'Setting the maximum file upload size in PHP to 5MB and memory limit to 256M...'
	exec_cmd "sed -i 's/\(upload_max_filesize =\) .*\(M\)/\1 5\2/g' /etc/php8/apache2/php.ini"
	exec_cmd "sed -i 's/\(memory_limit =\) .*\(M\)/\1 256\2/g' /etc/php8/apache2/php.ini"

	print_status 'Setting the maximum input variables in PHP to 3000...'
	exec_cmd "sed -i '/max_input_vars = 1000/a max_input_vars = 3000' /etc/php8/apache2/php.ini"

	set_up_simplerisk 'wwwrun'

	print_status 'Restarting Apache to load the new configuration...'
	exec_cmd 'systemctl restart apache2'

	generate_passwords

	print_status 'Configuring MySQL...'
	if [[ "${VER}" = 15* ]]; then
		exec_cmd "sed -i 's/\(\[mysqld\]\)/\1\nsql_mode=NO_ENGINE_SUBSTITUTION/g' /etc/my.cnf"
	fi
	exec_cmd "sed -i '$ a sql-mode=\"NO_ENGINE_SUBSTITUTION\"' /etc/my.cnf"
	exec_cmd "sed -i 's/,STRICT_TRANS_TABLES//g' /etc/my.cnf"

	if [[ "${VER}" = 15* ]]; then
		set_up_database	/var/log/mysql/mysqld.log
	else
		set_up_database
	fi
	
	print_status 'Setting the SimpleRisk database password...'
	exec_cmd "sed -i \"s/\(DB_PASSWORD', '\)simplerisk/\1${MYSQL_SIMPLERISK_PASSWORD}/\" /var/www/simplerisk/includes/config.php"
	exec_cmd "sed -i \"s/\(SIMPLERISK_INSTALLED', '\)false/\1true/\" /var/www/simplerisk/includes/config.php"

	print_status 'Restarting MySQL to load the new configuration...'
	exec_cmd 'systemctl restart mysql'

	print_status 'Removing the SimpleRisk database file...'
	exec_cmd 'rm -r /var/www/simplerisk/database.sql'

	print_status 'Setting up Backup cronjob...'
	set_up_backup_cronjob

	if [[ "${VER}" = 15* ]]; then
		print_status 'NOTE: SLES 15 does not have sendmail available on its repositories. You will need to configure postfix to be able to send emails.'
	fi
}

## Defer setup until we have the complete script
setup "${@:1}"
