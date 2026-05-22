#!/usr/bin/env bash

set -euo pipefail

readonly UBUNTU_OSVAR='Ubuntu'
readonly DEBIAN_OSVAR='Debian GNU/Linux'
readonly CENTOS_STREAM_OSVAR='CentOS Stream'
readonly RHEL_OSVAR='Red Hat Enterprise Linux'
readonly RHELS_OSVAR='Red Hat Enterprise Linux Server'
readonly SLES_OSVAR='SLES'
readonly SLES_15_SUPPORTED_SP="15.7"

readonly MYSQL_KEY_URL='https://repo.mysql.com/RPM-GPG-KEY-mysql-2025'
readonly MYSQL_GPG_KEY='B7B3B788A8D3785C' # Key taken from https://dev.mysql.com/doc/refman/8.4/en/checking-gpg-signature.html

#########################
## MAIN FLOW FUNCTIONS ##
#########################
setup (){
	# Auto-detect piped/non-interactive execution (e.g. curl | bash) and set
	# HEADLESS so ask_user is skipped and the install can proceed unattended.
	if ! [ -t 0 ] && [ ! -v HEADLESS ]; then HEADLESS=y; fi

	validate_args "${@:1}"

	check_root
	if [ ! -v HEADLESS ]; then
		if [ -v UNINSTALL ]; then
			ask_user_uninstall
		else
			ask_user
		fi
	fi
	load_os_variables
	validate_os_and_version
	if [ -v UNINSTALL ]; then
		perform_uninstallation
	else
		perform_installation
	fi
}

validate_args(){
	while [[ $# -gt 0 ]]
	do
		local key="${1}"
		case "${key}" in
			--yes)
				HEADLESS=y
				shift;;
			-d|--debug)
				DEBUG=y
				shift;;
			-t|--testing)
				TESTING=y
				shift;;
			--uninstall)
				UNINSTALL=y
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
}

check_root() {
	## Check to make sure we are running as root
	if [ ${EUID} -ne 0 ]; then
		print_error_message "This script must be run as root (unless verifying OS). Try: sudo bash"
	fi
}

ask_user(){
	if [ ! -t 0 ] && [ ! -v HEADLESS ]; then
		print_error_message "No interactive terminal available. Re-run with --yes."
	fi

	while true; do
		read -r -p 'This script will install SimpleRisk.  Proceed? [ Yes / (N)o ]: ' answer < /dev/tty
		case "${answer}" in
			Yes|yes|Y|y ) break;;
			No|no|N|n ) exit 1;;
			* ) echo "Please answer Yes or No.";;
		esac
	done
}

ask_user_uninstall(){
	if [ ! -t 0 ] && [ ! -v HEADLESS ]; then
		print_error_message "No interactive terminal available. Re-run with --yes."
	fi

	while true; do
		read -r -p 'This script will UNINSTALL SimpleRisk and remove all associated packages, files, and data. This action is IRREVERSIBLE. Proceed? [ Yes / (N)o ]: ' answer < /dev/tty
		case "${answer}" in
			Yes|yes|Y|y ) break;;
			No|no|N|n ) exit 1;;
			* ) echo "Please answer Yes or No.";;
		esac
	done
}

load_os_variables(){
	# freedesktop.org and systemd
	if [ -f /etc/os-release ]; then
		OS=$(grep -oP '^NAME=\K.*' /etc/os-release 2>/dev/null | tr -d '"')
		VER=$(grep -oP '^VERSION_ID=\K.*' /etc/os-release 2>/dev/null | tr -d '"')
	# linuxbase.org
	elif type lsb_release >/dev/null 2>&1; then
		OS=$(lsb_release -si)
		VER=$(lsb_release -sr)
	# For some versions of Debian/Ubuntu without lsb_release command
	elif [ -f /etc/lsb-release ]; then
		OS=$(grep -oP '^DISTRIB_ID=\K.*' /etc/lsb-release 2>/dev/null | tr -d '"')
		VER=$(grep -oP '^DISTRIB_RELEASE=\K.*' /etc/lsb-release 2>/dev/null | tr -d '"')
	# Older Debian/Ubuntu/etc.
	elif [ -f /etc/debian_version ]; then
		OS=$DEBIAN_OSVAR
		VER=$(cat /etc/debian_version)
	# Older SuSE/etc. or Red Hat, CentOS, etc.
	elif [ -f /etc/SuSe-release ] || [ -f /etc/redhat-release ]; then
		echo 'The SimpleRisk setup script cannot reliably determine which commands to run for this OS. Exiting.'
		exit 1
	# Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
	else
		OS=$(uname -s)
		VER=$(uname -r)
	fi
}

validate_os_and_version(){
	local valid
	case "${OS}" in
		"${UBUNTU_OSVAR}")
			if [ "${VER}" = '22.04' ] || [[ "${VER}" = 24.* ]] || [[ "${VER}" = 25.* ]]; then
				valid=y
				SETUP_TYPE=debian
			fi;;
		"${DEBIAN_OSVAR}")
			if [ "${VER}" = '12' ] || [ "${VER}" = '13' ]; then
				valid=y
				SETUP_TYPE=debian
			fi;;
		"${CENTOS_STREAM_OSVAR}")
			if [ "${VER}" = "9" ] || [ "${VER}" = "10" ]; then
				valid=y
				SETUP_TYPE=rhel
			fi;;
		"${RHEL_OSVAR}"|"${RHELS_OSVAR}")
			if [[ "${VER}" = 9* ]] || [[ "${VER}" = 10* ]]; then
				valid=y
				SETUP_TYPE=rhel
			fi;;
		"${SLES_OSVAR}")
			if [[ "${VER}" = "$SLES_15_SUPPORTED_SP" ]]; then
				valid=y
				local php_module
				# Grab module where php8 is available
				php_module=$(zypper search-packages php8 | awk '/^php8[[:space:]]/ { sub(/\(.*/, ""); sub(/^php8[[:space:]]+/, ""); sub(/[[:space:]]+$/, ""); print }')
				if ! sudo suseconnect --list-extensions | grep -F "$php_module" | grep -q "Activated"; then
					print_error_message "$php_module is not enabled on your subscription. Please enable it before running this installer."
				fi
				if [ ! -v HEADLESS ]; then
					read -r -p 'Before continuing, SLES 15 does not have sendmail available. Proceed? [ Yes / (No) ]: ' answer < /dev/tty
					case "${answer}" in
						Yes|yes|Y|y ) SETUP_TYPE=suse;;
						* ) exit 1;;
					esac
				else
					echo "This will install postfix. You will need to configure it later."
					SETUP_TYPE=suse
				fi
			fi;;
		*)
			local unknown=y;;
	esac

	if [ -n "${valid:-}" ]; then
		echo "Detected OS is ${OS} ${VER}, which is supported by this script."
	elif [ -z "${valid:-}" ] && [ ! -v unknown ]; then
		echo "Detected OS is ${OS} ${VER}, but this version is not currently supported by this script."
		exit 1
	else
		echo "Detected OS is ${OS}, but it is unsupported by this script."
		exit 1
	fi
}

perform_installation() {
	local current_simplerisk_version
	current_simplerisk_version=$(get_current_simplerisk_version)

	case "${SETUP_TYPE:-}" in
		debian) setup_ubuntu_debian "$current_simplerisk_version";;
		rhel) setup_centos_rhel "$current_simplerisk_version";;
		suse) setup_suse "$current_simplerisk_version";;
		*) print_error_message "Could not validate the setup type. Check the perform_installation and validate_os_and_version functions.";;
	esac

	success_final_message
}

perform_uninstallation() {
	case "${SETUP_TYPE:-}" in
		debian) uninstall_ubuntu_debian;;
		rhel) uninstall_centos_rhel;;
		suse) uninstall_suse;;
		*) print_error_message "Could not validate the setup type. Check the perform_uninstallation and validate_os_and_version functions.";;
	esac

	uninstall_final_message
}

#########################
## AUXILIARY FUNCTIONS ##
#########################
print_status() {
	echo
	echo "## ${1}"
	echo
}

print_error_message() {
	echo
	echo "!!! ERROR: ${1} !!!"
	echo
	exit 1
}

exec_cmd(){
	exec_cmd_nobail "${1}" || bail
}

exec_cmd_nobail() {
	local no_log=""
	if [ ! -v DEBUG ]; then
		no_log='> /dev/null 2>&1'
	fi

	echo "+ ${1}"
	bash -c "${1} ${no_log}"
}

# run_cmd / run_cmd_nobail: array-safe wrappers that pass arguments directly
# to the target program (no shell double-evaluation).  Use these for simple
# commands with no pipes, redirects, or compound operators.
run_cmd_nobail() {
	if [ -v DEBUG ]; then printf '+ %s\n' "$*"; fi
	if [ ! -v DEBUG ]; then
		"$@" > /dev/null 2>&1
	else
		"$@"
	fi
}
run_cmd() { run_cmd_nobail "$@" || bail; }

create_random_password() {
	local char_pattern='A-Za-z0-9'
	if [ -n "${2:-}" ]; then
		char_pattern=$char_pattern'!?^@%'
	fi
	# Disabling useless echo (mandatory with set u)
	# shellcheck disable=SC2005
	echo "$(< /dev/urandom tr -dc "${char_pattern}" | head -c"${1:-20}")"
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
	# RHEL 9, 10: /var/log/mysqld.log
	# SLES 15:  /var/log/mysql/mysqld.log
	local password_flag
	if [ -n "${1:-}" ]; then
		local initial_root_password
		initial_root_password=$(grep Note "$1" | awk -F " " '{print $NF}')
		local temp_password
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

	print_status 'Setup the config.php file'
	exec_cmd "cp /var/www/simplerisk/includes/config.sample.php /var/www/simplerisk/includes/config.php"
	exec_cmd "sed -i \"s/\(DB_HOSTNAME', '\)__DB_HOSTNAME__/\1localhost/\" /var/www/simplerisk/includes/config.php"
	exec_cmd "sed -i \"s/\(DB_PORT', '\)__DB_PORT__/\13306/\" /var/www/simplerisk/includes/config.php"
	exec_cmd "sed -i \"s/\(DB_USERNAME', '\)__DB_USERNAME__/\1simplerisk/\" /var/www/simplerisk/includes/config.php"
	exec_cmd "sed -i \"s/\(DB_PASSWORD', '\)__DB_PASSWORD__/\1${MYSQL_SIMPLERISK_PASSWORD}/\" /var/www/simplerisk/includes/config.php"
	exec_cmd "sed -i \"s/\(DB_DATABASE', '\)__DB_DATABASE__/\1simplerisk/\" /var/www/simplerisk/includes/config.php"
}

set_php_settings() {
	# $1 receives the path to php settings file
	print_status 'Setting the maximum file upload size in PHP to 5MB and memory limit to 256M...'
	run_cmd sed -i "s/\(upload_max_filesize =\) .*/\1 5M/g" "$1"
	run_cmd sed -i "s/\(memory_limit =\) .*/\1 256M/g" "$1"

	print_status 'Setting the maximum input variables in PHP to 3000...'
	run_cmd sed -i "s/\(;\|\#\)\?\(max_input_vars =\).*/\2 3000/g" "$1"
}

set_up_simplerisk() {
# $1 receives the user to set the ownership of the simplerisk directory
# $2 receives current SimpleRisk's version
	print_status 'Downloading the latest SimpleRisk release to /var/www/simplerisk...'
	if [ ! -d /var/www ]; then
		run_cmd mkdir -p /var/www/
	elif [ -d /var/www/html ]; then
		run_cmd rm -r /var/www/html
	fi
	exec_cmd "cd /var/www && wget https://simplerisk-downloads.s3.amazonaws.com/public/bundles/simplerisk-${2}.tgz"
	exec_cmd "cd /var/www && tar xvzf simplerisk-${2}.tgz"
	run_cmd rm -f "/var/www/simplerisk-${2}.tgz"
	exec_cmd "cd /var/www/simplerisk && wget https://github.com/simplerisk/database/raw/master/simplerisk-en-${2}.sql -O database.sql"
	run_cmd chown -R "${1}:" /var/www/simplerisk
}

set_up_backup_cronjob() {
	exec_cmd "(crontab -l 2>/dev/null; echo '* * * * * $(which php) -f /var/www/simplerisk/cron/cron.php') | crontab -"
}

set_up_simplerisk_log() {
	# $1 receives the apache user that should own the log directory and file
	print_status 'Creating SimpleRisk log directory and file...'
	run_cmd mkdir -p /var/log/simplerisk
	run_cmd touch /var/log/simplerisk/simplerisk.log
	run_cmd chown -R "${1}:" /var/log/simplerisk
	run_cmd chmod 750 /var/log/simplerisk
	run_cmd chmod 640 /var/log/simplerisk/simplerisk.log
}

get_current_simplerisk_version() {
	curl -sL "https://updates${TESTING:+-test}.simplerisk.com/releases.xml" | grep -oP '<release version=(.*)>' | head -n1 | cut -d '"' -f 2
}

get_installed_php_version() {
	php -v | grep -E '^PHP [[:digit:]]' | awk -F ' ' '{print $2}' | awk -F '.' '{print $NR"."$2}'
}

#######################
## MESSAGE FUNCTIONS ##
#######################
success_final_message(){
	print_status 'Check /root/passwords.txt for the MySQL root and simplerisk passwords.'
	print_status 'As these passwords are stored in clear text, we recommend immediately moving them into a password manager and deleting this file.'
	print_status 'INSTALLATION COMPLETED SUCCESSFULLY'
}

uninstall_final_message(){
	print_status 'UNINSTALLATION COMPLETED SUCCESSFULLY'
	print_status 'SimpleRisk and its associated components have been removed from this system.'
	print_status 'Note: Base packages (wget, gnupg, cron, etc.) that were present before installation may remain on the system.'
}

print_help() {
        cat << EOC

Script to set up or uninstall SimpleRisk on a server.

./simplerisk-setup [-d|--debug] [--yes] [-h|--help] [--uninstall]

Flags:
-d|--debug:            Shows the output of the commands being run by this script
-t|--testing:          Picks the current testing version
--uninstall:           Removes SimpleRisk and all associated packages, services, and data
                         (Apache/httpd, MySQL, PHP, sendmail/postfix, firewall rules).
                         WARNING: This action is irreversible and will destroy all SimpleRisk data.
--yes:                 Will answer yes on every question (Use it carefully)
-h|--help:             Shows instructions on how to use this script
EOC
}

bail() {
	print_error_message 'The command exited with failure. Verify the command output or run the script in debug mode (-d|--debug).'
}

remove_backup_cronjob() {
	(crontab -l 2>/dev/null | grep -v 'simplerisk/cron/cron.php') | crontab - 2>/dev/null || true
}

get_mysql_root_password() {
	if [ -f /root/passwords.txt ]; then
		grep 'MYSQL ROOT PASSWORD:' /root/passwords.txt | awk -F ': ' '{print $2}'
	fi
}

drop_simplerisk_database() {
	local root_password
	root_password=$(get_mysql_root_password)
	if [ -n "${root_password}" ]; then
		exec_cmd_nobail "mysql -uroot --password='${root_password}' -e \"DROP DATABASE IF EXISTS simplerisk\""
		exec_cmd_nobail "mysql -uroot --password='${root_password}' -e \"DROP USER IF EXISTS 'simplerisk'@'localhost'\""
		exec_cmd_nobail "mysql -uroot --password='${root_password}' -e \"FLUSH PRIVILEGES\""
	else
		print_status 'WARNING: Could not find MySQL root password in /root/passwords.txt. Skipping database removal.'
		print_status 'You may need to manually drop the simplerisk database and user.'
	fi
}

########################
## OS SETUP FUNCTIONS ##
########################
# In all functions, $1 will receive SimpleRisk's current version
setup_ubuntu_debian(){
	export DEBIAN_FRONTEND=noninteractive

	print_status "Running SimpleRisk ${1} installer..."

	print_status 'Populating apt-get cache...'
	run_cmd apt-get update

	# Add PHP8/MySQL repos for Debian
	if [ "${OS}" = "${DEBIAN_OSVAR}" ]; then
		run_cmd mkdir -p /etc/apt/keyrings
		local apt_php_version=8.5

		print_status 'Install gnupg to handle keyrings...'
		run_cmd apt-get install -y gnupg

		print_status "Adding Ondrej's repository with PHP8"
		# Download the Sury PHP signing key and verify its fingerprint before trusting it.
		run_cmd curl -fsSL https://packages.sury.org/php/apt.gpg -o /etc/apt/keyrings/sury-php.gpg
		local sury_expected_fp="15058500A0235D97F5D10063B188E2B695BD4743"
		local sury_actual_fp
		sury_actual_fp=$(gpg --no-default-keyring \
			--keyring /etc/apt/keyrings/sury-php.gpg \
			--fingerprint --with-colons 2>/dev/null | awk -F: '/^fpr/{print $10; exit}')
		if [[ "${sury_actual_fp}" != "${sury_expected_fp}" ]]; then
			rm -f /etc/apt/keyrings/sury-php.gpg
			print_error_message "Sury PHP GPG key fingerprint mismatch (got '${sury_actual_fp}', expected '${sury_expected_fp}') — aborting."
		fi
		exec_cmd "echo 'deb [signed-by=/etc/apt/keyrings/sury-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main' | sudo tee /etc/apt/sources.list.d/sury-php.list"

		print_status 'Adding MySQL 8 repository'
		# Download the signing key directly from MySQL (more reliable than keyservers).
		exec_cmd "curl -fsSL '$MYSQL_KEY_URL' | gpg --dearmor -o /etc/apt/trusted.gpg.d/mysql.gpg"
		exec_cmd "echo 'deb [signed-by=/etc/apt/trusted.gpg.d/mysql.gpg] https://repo.mysql.com/apt/$(lsb_release -si | tr '[:upper:]' '[:lower:]')/ $(lsb_release -sc) mysql-8.4-lts' | sudo tee /etc/apt/sources.list.d/mysql.list"

		print_status 'Re-populating apt-get cache with added repos...'
		run_cmd apt-get update
	fi

	print_status 'Updating current packages (this may take a bit)...'
	run_cmd apt-get dist-upgrade -qq --assume-yes

	if [ "${OS}" = "${UBUNTU_OSVAR}" ]; then
		print_status 'Installing lamp-server...'
		run_cmd apt-get install -y 'lamp-server^'
		print_status 'Installing cron...'
		run_cmd apt-get install -y cron
	else
		print_status 'Installing Apache...'
		run_cmd apt-get install -y apache2

		print_status 'Installing MySQL...'
		run_cmd apt-get install -y mysql-server

		print_status 'Installing PHP...'
		run_cmd apt-get install -y "php${apt_php_version:-}" "php${apt_php_version:-}-mysql" "libapache2-mod-php${apt_php_version:-}"

		if [ "${OS}" = "${DEBIAN_OSVAR}" ]; then
			if [ "${VER}" = '12' ] || [ "${VER}" = '13' ]; then
				print_status 'Installing crontab'
				run_cmd apt-get install -y cron
			fi
		fi
	fi

	print_status 'Installing PHP development libraries...'
	run_cmd apt-get install -y "php${apt_php_version:-}-dev"

	for module in xml mbstring mysql ldap curl gd zip intl; do
		print_status "Installing the $module module for PHP..."
		run_cmd apt-get install -y "php${apt_php_version:-}-$module"
	done

	print_status 'Enabling the ldap module in PHP...'
	run_cmd phpenmod ldap

	print_status 'Enabling SSL for Apache...'
	run_cmd a2enmod rewrite
	run_cmd a2enmod ssl
	run_cmd a2ensite default-ssl

	print_status 'Installing sendmail...'
	run_cmd apt-get install -y sendmail

	print_status 'Configuring secure settings for Apache...'
	run_cmd sed -i 's/\(SSLProtocol\) all -SSLv3/\1 TLSv1.2/g' /etc/apache2/mods-enabled/ssl.conf
	run_cmd sed -i 's/#\?\(SSLHonorCipherOrder\) on/\1 on/g' /etc/apache2/mods-enabled/ssl.conf
	run_cmd sed -i 's/\(ServerTokens\) OS/\1 Prod/g' /etc/apache2/conf-enabled/security.conf
	run_cmd sed -i 's/\(ServerSignature\) On/\1 Off/g' /etc/apache2/conf-enabled/security.conf

	# Obtaining php version to find settings file path
	[ -n "${apt_php_version:-}" ] && php_version=$apt_php_version || php_version=$(get_installed_php_version)

	set_php_settings "/etc/php/$php_version/apache2/php.ini"

	set_up_simplerisk 'www-data' "${1}"
	set_up_simplerisk_log 'www-data'

	print_status 'Configuring Apache...'
	run_cmd sed -i 's|\(/var/www/\)html|\1simplerisk|g' /etc/apache2/sites-enabled/000-default.conf
	if ! grep -q 'RewriteEngine On' /etc/apache2/sites-enabled/000-default.conf; then
		exec_cmd "sed -i '/^<\/VirtualHost>/i \\\tRewriteEngine On\n\tRewriteCond %{HTTPS} !=on\n\tRewriteRule ^/?(.*) https://%{SERVER_NAME}/\$1 [R,L]' /etc/apache2/sites-enabled/000-default.conf"
	fi
	run_cmd sed -i 's|/var/www/html|/var/www/simplerisk|g' /etc/apache2/sites-enabled/default-ssl.conf
	if ! grep -q 'AllowOverride all' /etc/apache2/sites-enabled/default-ssl.conf; then
		exec_cmd "sed -i '/<\/Directory>/a \\\t\t<Directory \"\/var\/www\/simplerisk\">\n\t\t\tAllowOverride all\n\t\t\tallow from all\n\t\t\tOptions -Indexes\n\t\t<\/Directory>' /etc/apache2/sites-enabled/default-ssl.conf"
	fi

	print_status 'Configuring Sendmail...'
	# /etc/hosts may be a bind-mount (e.g. Docker) and cannot be renamed by
	# `sed -i`.  Write to a temp file then overwrite the original in place.
	exec_cmd "sed 's/\(localhost\)/\1 $(hostname)/g' /etc/hosts > /tmp/hosts.bak && cat /tmp/hosts.bak > /etc/hosts && rm -f /tmp/hosts.bak"
	exec_cmd 'yes | sendmailconfig'
	run_cmd service sendmail restart

	print_status 'Restarting Apache to load the new configuration...'
	run_cmd service apache2 restart

	generate_passwords

	print_status 'Ensuring MySQL database server is running...'
	exec_cmd 'service mysql status > /dev/null 2>&1 || service mysql start'

	print_status 'Configuring MySQL...'
	exec_cmd "sed -i '$ a sql-mode=\"NO_ENGINE_SUBSTITUTION\"' /etc/mysql/mysql.conf.d/mysqld.cnf"
	set_up_database

	print_status 'Restarting MySQL to load the new configuration...'
	run_cmd service mysql restart

	print_status 'Removing the SimpleRisk database file...'
	run_cmd rm -r /var/www/simplerisk/database.sql

	print_status 'Setting up Backup cronjob...'
	set_up_backup_cronjob

	print_status 'Installing UFW firewall...'
	run_cmd apt-get install -y ufw

	print_status 'Enabling UFW firewall...'
	run_cmd ufw allow ssh
	run_cmd ufw allow http
	run_cmd ufw allow https
	run_cmd ufw --force enable
}

setup_centos_rhel(){
	print_status "Running SimpleRisk ${1} installer..."
	local major_version="${VER%%.*}"

	print_status "Updating packages. This may take some time."
	run_cmd dnf -y update

	print_status 'Installing the wget package...'
	run_cmd dnf -y install wget

	print_status 'Installing Firewalld...'
	run_cmd dnf -y install firewalld

	print_status 'Enabling MySQL 8 repositories...'
	run_cmd rpm -Uvh "https://dev.mysql.com/get/mysql84-community-release-el${major_version}-2.noarch.rpm"
	run_cmd rpm --import "$MYSQL_KEY_URL"

	print_status 'Enabling PHP 8 repositories...'
	run_cmd dnf -y install "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${major_version}.noarch.rpm"
	case $major_version in
		8) run_cmd rpm --import https://rpms.remirepo.net/RPM-GPG-KEY-remi2018;;
		9) run_cmd rpm --import https://rpms.remirepo.net/RPM-GPG-KEY-remi2021;;
		10) run_cmd rpm --import https://rpms.remirepo.net/RPM-GPG-KEY-remi2025;;
	esac
	run_cmd dnf -y install "https://rpms.remirepo.net/enterprise/remi-release-${major_version}.rpm"
	run_cmd dnf -y update


	print_status 'Installing PHP for Apache...'
	run_cmd dnf -y module reset php
	run_cmd dnf -y module enable php:remi-8.5
	run_cmd dnf -y install httpd php php-cli php-common php-mysqlnd php-mbstring php-opcache php-gd php-zip php-json php-ldap php-curl php-xml php-intl php-process

	set_php_settings /etc/php.ini

	print_status 'Installing the MySQL database server...'
	# On CentOS/RHEL 10, AppStream ships mysql8.4-server which conflicts with
	# mysql-community-server (same files).  Exclude it explicitly so DNF does
	# not pull it in as a weak dependency.  The exclude is a no-op on el9/el8
	# where mysql8.4-server does not exist in any enabled repo.
	# The mysql84-community-release RPM also enables a mysql-9.x-lts-community
	# repo; disable it so DNF resolves mysql-community-server from 8.4, not 9.x.
	run_cmd dnf install -y mysql-community-server --exclude 'mariadb*' --exclude 'mysql8.4*' --disablerepo='mysql-9*'

	print_status 'Enabling and starting MySQL database server...'
	run_cmd systemctl enable mysqld
	run_cmd systemctl start mysqld

	if [[ "${VER}" = 8* ]]; then
		run_cmd dnf clean all
		exec_cmd 'rm -rf /var/cache/dnf/remi-*a'
		run_cmd dnf -y update
	fi

	print_status 'Installing mod_ssl'
	run_cmd dnf -y install mod_ssl

	print_status 'Installing sendmail'
	run_cmd dnf -y install sendmail sendmail-cf m4

	set_up_simplerisk 'apache' "${1}"
	set_up_simplerisk_log 'apache'

	print_status 'Configuring Apache...'
	run_cmd sed -i 's|#\?\(DocumentRoot "/var/www/\)html"|\1simplerisk"|' /etc/httpd/conf.d/ssl.conf
	exec_cmd 'mv /etc/httpd/conf.d/welcome.conf{,.disabled}'
	exec_cmd 'mkdir /etc/httpd/sites-{available,enabled}'
	run_cmd sed -i 's|\(DocumentRoot "/var/www\).*|\1"|g' /etc/httpd/conf/httpd.conf
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
	RewriteRule ^/?(.*) https://%{SERVER_NAME}/\$1 [R,L]
</VirtualHost>
EOF

	if ! grep -q 'AllowOverride all' /etc/httpd/conf.d/ssl.conf; then
		exec_cmd "sed -i '/<\/Directory>/a \\\t\t<Directory \"\/var\/www\/simplerisk\">\n\t\t\tAllowOverride all\n\t\t\tallow from all\n\t\t\tOptions -Indexes\n\t\t<\/Directory>' /etc/httpd/conf.d/ssl.conf"
	fi
	run_cmd sed -i 's/#\(LoadModule mpm_prefork\)/\1/g' /etc/httpd/conf.modules.d/00-mpm.conf
	run_cmd sed -i 's/\(LoadModule mpm_event\)/#\1/g' /etc/httpd/conf.modules.d/00-mpm.conf

	generate_passwords

	print_status 'Configuring MySQL...'
	set_up_database	/var/log/mysqld.log

	# Write sql_mode to a dedicated drop-in file so it is read last (alphabetically
	# "zz-") and is not overridden by any vendor-supplied file in /etc/my.cnf.d/.
	# The same setting is applied via SET GLOBAL after the restart as a safety net
	# for MySQL 8.4+ where config-file precedence changed.
	printf '[mysqld]\nsql_mode=ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION\n' \
		> /etc/my.cnf.d/zz-simplerisk.cnf

	print_status 'Restarting MySQL to load the new configuration...'
	run_cmd systemctl restart mysqld
	exec_cmd "mysql -uroot -p\"${NEW_MYSQL_ROOT_PASSWORD}\" \
		-e \"SET GLOBAL sql_mode='ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';\" \
		2>/dev/null"

	print_status 'Removing the SimpleRisk database file...'
	run_cmd rm -r /var/www/simplerisk/database.sql
	print_status 'Setting up Backup cronjob...'
	set_up_backup_cronjob

	print_status 'Enabling and starting the Apache web server...'
	run_cmd systemctl enable httpd
	run_cmd systemctl start httpd

	print_status 'Configuring and starting Sendmail...'
	exec_cmd "sed 's/\(localhost\)/\1 $(hostname)/g' /etc/hosts > /tmp/hosts.bak && cat /tmp/hosts.bak > /etc/hosts && rm -f /tmp/hosts.bak"
	run_cmd systemctl start sendmail

	print_status 'Opening Firewall for HTTP/HTTPS traffic'
	run_cmd systemctl enable firewalld
	run_cmd systemctl start firewalld
	for service in http https ssh; do
		run_cmd firewall-cmd --permanent --zone=public "--add-service=${service}"
	done
	run_cmd firewall-cmd --reload

	print_status 'Configuring SELinux for SimpleRisk...'
	value_one_permissions=('httpd_builtin_scripting' 'httpd_can_network_connect' 'httpd_can_sendmail' 'httpd_dbus_avahi' 'httpd_enable_cgi' 'httpd_read_user_content' 'httpd_tty_comm')
	for permission in "${value_one_permissions[@]}"; do
		run_cmd setsebool -P "$permission=1"
	done
	value_nil_permissions=('allow_httpd_anon_write' 'allow_httpd_mod_auth_ntlm_winbind' 'allow_httpd_mod_auth_pam' 'allow_httpd_sys_script_anon_write' 'httpd_can_check_spam' 'httpd_can_network_connect_cobbler' 'httpd_can_network_connect_db' 'httpd_can_network_memcache' 'httpd_can_network_relay' 'httpd_dbus_sssd' 'httpd_enable_ftp_server' 'httpd_enable_homedirs' 'httpd_execmem' 'httpd_manage_ipa' 'httpd_run_preupgrade' 'httpd_run_stickshift' 'httpd_serve_cobbler_files' 'httpd_setrlimit' 'httpd_ssi_exec' 'httpd_tmp_exec' 'httpd_use_cifs' 'httpd_use_fusefs' 'httpd_use_gpg' 'httpd_use_nfs' 'httpd_use_openstack' 'httpd_verify_dns')
	for permission in "${value_nil_permissions[@]}"; do
		run_cmd setsebool -P "$permission=0"
	done
	run_cmd chcon -R -t httpd_sys_rw_content_t /var/www/simplerisk
	run_cmd chcon -R -t httpd_log_t /var/log/simplerisk
}

setup_suse(){
	print_status "Running SimpleRisk ${1} installer..."

	print_status 'Populating zypper cache...'
	run_cmd zypper -n update

	if ! rpm -q mysql84-community-release; then
		print_status 'Adding MySQL 8 repository...'
		run_cmd rpm -Uvh https://dev.mysql.com/get/mysql84-community-release-sl15-1.noarch.rpm
		run_cmd rpm --import "$MYSQL_KEY_URL"
	fi

	print_status 'Installing Apache...'
	run_cmd zypper -n install apache2

	print_status 'Enabling Apache on reboot...'
	run_cmd systemctl enable apache2

	print_status 'Starting Apache...'
	run_cmd systemctl start apache2

	print_status 'Installing MySQL 8...'
	run_cmd zypper -n install mysql-community-server

	print_status 'Enabling MySQL on reboot...'
	run_cmd systemctl enable mysql

	print_status 'Starting MySQL...'
	run_cmd systemctl start mysql

	print_status 'Installing PHP 8...'
	run_cmd zypper -n install php8 php8-mysql apache2-mod_php8 php8-ldap php8-curl php8-zlib php8-phar php8-mbstring php8-intl php8-posix php8-gd php8-zip php-xml

	if [ "${VER}" = "${SLES_15_SUPPORTED_SP}" ]; then
		print_status 'Enabling PHP and Apache modules...'
		for module in php8 rewrite ssl mod_ssl; do
			run_cmd a2enmod "$module"
		done
	fi

	print_status 'Enabling Rewrite Module for Apache...'
	if [ "${VER}" = "${SLES_15_SUPPORTED_SP}" ]; then
		echo 'LoadModule rewrite_module         /usr/lib64/apache2-prefork/mod_rewrite.so' >> /etc/apache2/loadmodule.conf
	fi

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
	RewriteRule ^/?(.*) https://%{SERVER_NAME}/\$1 [R,L]
</VirtualHost>
EOF

	generate_passwords

	# Generate the OpenSSL private key
	exec_cmd 'openssl rand -hex 50 > /tmp/pass_openssl.txt'
	run_cmd openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -aes-256-cbc -pass file:/tmp/pass_openssl.txt -out /etc/apache2/ssl.key/simplerisk.pass.key
	run_cmd openssl pkey -passin file:/tmp/pass_openssl.txt -in /etc/apache2/ssl.key/simplerisk.pass.key -out /etc/apache2/ssl.key/simplerisk.key

	# Remove the original key file
	run_cmd rm /etc/apache2/ssl.key/simplerisk.pass.key /tmp/pass_openssl.txt

	# Generate the CSR
	run_cmd openssl req -new -key /etc/apache2/ssl.key/simplerisk.key -out /etc/apache2/ssl.csr/simplerisk.csr -subj /CN=simplerisk

	# Create the Certificate
	run_cmd openssl x509 -req -days 365 -in /etc/apache2/ssl.csr/simplerisk.csr -signkey /etc/apache2/ssl.key/simplerisk.key -out /etc/apache2/ssl.crt/simplerisk.crt

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
	run_cmd sed -i 's/\(SSLProtocol\).*/\1 TLSv1.2/g' /etc/apache2/ssl-global.conf
	run_cmd sed -i 's/#\?\(SSLHonorCipherOrder\)/\1/g' /etc/apache2/ssl-global.conf
	#run_cmd sed -i 's/ServerTokens OS/ServerTokens Prod/g' /etc/apache2/conf-enabled/security.conf
	#run_cmd sed -i 's/ServerSignature On/ServerSignature Off/g' /etc/apache2/conf-enabled/security.conf

	set_php_settings /etc/php8/apache2/php.ini

	print_status 'Specifying the MySQL socket path...'
	for extension in mysqli pdo_mysql; do
		exec_cmd "sed -i 's|\($extension.default_socket\).*|\1=/var/lib/mysql/mysql.sock|' /etc/php8/apache2/php.ini"
	done

	set_up_simplerisk 'wwwrun' "${1}"
	set_up_simplerisk_log 'wwwrun'

	print_status 'Restarting Apache to load the new configuration...'
	run_cmd systemctl restart apache2

	print_status 'Configuring MySQL...'
	if [[ "${VER}" = 15* ]]; then
		exec_cmd "sed -i 's/\(\[mysqld\]\)/\1\nsql_mode=NO_ENGINE_SUBSTITUTION/g' /etc/my.cnf"
	fi
	exec_cmd "sed -i '$ a sql-mode=\"NO_ENGINE_SUBSTITUTION\"' /etc/my.cnf"
	run_cmd sed -i 's/,STRICT_TRANS_TABLES//g' /etc/my.cnf

	if [[ "${VER}" = 15* ]]; then
		set_up_database	/var/log/mysql/mysqld.log
	else
		set_up_database
	fi

	print_status 'Restarting MySQL to load the new configuration...'
	run_cmd systemctl restart mysql

	print_status 'Removing the SimpleRisk database file...'
	run_cmd rm -r /var/www/simplerisk/database.sql

	print_status 'Setting up Backup cronjob...'
	set_up_backup_cronjob

	if [[ "${VER}" = 15* ]]; then
		print_status 'NOTE: SLES 15 does not have sendmail available on its repositories. You will need to configure postfix to be able to send emails.'
	fi
}

###########################
## OS UNINSTALL FUNCTIONS ##
###########################
uninstall_ubuntu_debian(){
	export DEBIAN_FRONTEND=noninteractive

	print_status 'Removing SimpleRisk cron job...'
	remove_backup_cronjob

	print_status 'Dropping SimpleRisk database and user...'
	drop_simplerisk_database

	print_status 'Stopping services...'
	run_cmd_nobail service apache2 stop
	run_cmd_nobail service mysql stop
	run_cmd_nobail service sendmail stop

	print_status 'Removing SimpleRisk application files...'
	run_cmd_nobail rm -rf /var/www/simplerisk

	print_status 'Removing SimpleRisk log directory...'
	run_cmd_nobail rm -rf /var/log/simplerisk

	print_status 'Removing installed packages...'
	exec_cmd_nobail "apt-get purge -y 'php*' 'libapache2-mod-php*' apache2 apache2-utils apache2-bin mysql-server mysql-client mysql-common sendmail sendmail-bin"
	run_cmd_nobail apt-get autoremove -y
	run_cmd_nobail apt-get autoclean

	if [ "${OS}" = "${DEBIAN_OSVAR}" ]; then
		print_status 'Removing added repositories and keys...'
		run_cmd_nobail rm -f /etc/apt/sources.list.d/sury-php.list
		run_cmd_nobail rm -f /etc/apt/sources.list.d/mysql.list
		run_cmd_nobail rm -f /etc/apt/keyrings/sury-php.gpg
		run_cmd_nobail rm -f /etc/apt/trusted.gpg.d/mysql.gpg
		run_cmd_nobail apt-get update
	fi

	print_status 'Removing UFW firewall rules for SimpleRisk...'
	run_cmd_nobail ufw delete allow http
	run_cmd_nobail ufw delete allow https

	print_status 'Removing MySQL password file...'
	run_cmd_nobail rm -f /root/passwords.txt
}

uninstall_centos_rhel(){
	print_status 'Removing SimpleRisk cron job...'
	remove_backup_cronjob

	print_status 'Dropping SimpleRisk database and user...'
	drop_simplerisk_database

	print_status 'Stopping and disabling services...'
	run_cmd_nobail systemctl stop httpd
	run_cmd_nobail systemctl disable httpd
	run_cmd_nobail systemctl stop mysqld
	run_cmd_nobail systemctl disable mysqld
	run_cmd_nobail systemctl stop sendmail

	print_status 'Removing SimpleRisk application files...'
	run_cmd_nobail rm -rf /var/www/simplerisk

	print_status 'Removing SimpleRisk log directory...'
	run_cmd_nobail rm -rf /var/log/simplerisk

	print_status 'Removing SimpleRisk Apache virtual host config...'
	run_cmd_nobail rm -f /etc/httpd/sites-enabled/simplerisk.conf
	run_cmd_nobail rm -rf /etc/httpd/sites-available /etc/httpd/sites-enabled
	run_cmd_nobail sed -i '/IncludeOptional sites-enabled\/*.conf/d' /etc/httpd/conf/httpd.conf
	exec_cmd_nobail 'mv /etc/httpd/conf.d/welcome.conf.disabled /etc/httpd/conf.d/welcome.conf 2>/dev/null || true'

	print_status 'Removing installed packages...'
	exec_cmd_nobail "dnf -y remove httpd mod_ssl 'php*' mysql-community-server mysql-community-client sendmail sendmail-cf m4"
	run_cmd_nobail dnf -y autoremove

	print_status 'Removing MySQL and PHP repositories...'
	local major_version="${VER%%.*}"
	exec_cmd_nobail "rpm -e mysql84-community-release-el${major_version} 2>/dev/null || true"
	run_cmd_nobail dnf -y remove epel-release
	exec_cmd_nobail "rpm -e remi-release-${major_version} 2>/dev/null || true"
	run_cmd_nobail dnf clean all

	print_status 'Removing firewall rules for SimpleRisk...'
	run_cmd_nobail firewall-cmd --permanent --zone=public --remove-service=http
	run_cmd_nobail firewall-cmd --permanent --zone=public --remove-service=https
	run_cmd_nobail firewall-cmd --reload

	print_status 'Removing MySQL password file...'
	run_cmd_nobail rm -f /root/passwords.txt
}

uninstall_suse(){
	print_status 'Removing SimpleRisk cron job...'
	remove_backup_cronjob

	print_status 'Dropping SimpleRisk database and user...'
	drop_simplerisk_database

	print_status 'Stopping and disabling services...'
	run_cmd_nobail systemctl stop apache2
	run_cmd_nobail systemctl disable apache2
	run_cmd_nobail systemctl stop mysql
	run_cmd_nobail systemctl disable mysql

	print_status 'Removing SimpleRisk application files...'
	run_cmd_nobail rm -rf /var/www/simplerisk

	print_status 'Removing SimpleRisk log directory...'
	run_cmd_nobail rm -rf /var/log/simplerisk

	print_status 'Removing SimpleRisk Apache virtual host and SSL config...'
	run_cmd_nobail rm -f /etc/apache2/vhosts.d/simplerisk.conf
	run_cmd_nobail rm -f /etc/apache2/vhosts.d/ssl.conf
	run_cmd_nobail rm -f /etc/apache2/ssl.key/simplerisk.key
	run_cmd_nobail rm -f /etc/apache2/ssl.csr/simplerisk.csr
	run_cmd_nobail rm -f /etc/apache2/ssl.crt/simplerisk.crt
	run_cmd_nobail sed -i '/LoadModule rewrite_module.*mod_rewrite.so/d' /etc/apache2/loadmodule.conf

	print_status 'Removing installed packages...'
	exec_cmd_nobail "zypper -n remove apache2 mysql-community-server 'php8*' apache2-mod_php8"
	run_cmd_nobail zypper -n autoremove

	print_status 'Removing MySQL repository...'
	exec_cmd_nobail 'rpm -e mysql84-community-release-sl15 2>/dev/null || true'

	print_status 'Removing MySQL password file...'
	run_cmd_nobail rm -f /root/passwords.txt
}

## Defer setup until we have the complete script
setup "${@:1}"
