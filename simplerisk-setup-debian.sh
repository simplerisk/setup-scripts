#!/usr/bin/env bash

set -euo pipefail

readonly MYSQL_KEY_URL='https://repo.mysql.com/RPM-GPG-KEY-mysql-2023'
readonly UBUNTU_OSVAR='Ubuntu'
readonly DEBIAN_OSVAR='Debian GNU/Linux'

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
	local password_flag
	exec_cmd "mysql -uroot mysql -e 'CREATE DATABASE simplerisk'${password_flag:-}"
	exec_cmd "mysql -uroot mysql -e \"CREATE USER 'simplerisk'@'localhost' IDENTIFIED BY '${MYSQL_SIMPLERISK_PASSWORD}'\"${password_flag:-}"
	exec_cmd "mysql -uroot simplerisk -e '\\. /var/www/simplerisk/database.sql'${password_flag:-}"
	exec_cmd "mysql -uroot simplerisk -e \"GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, REFERENCES, INDEX, ALTER ON simplerisk.* TO 'simplerisk'@'localhost'\"${password_flag:-}"
	exec_cmd "mysql -u root mysql -e \"ALTER USER 'root'@'localhost' IDENTIFIED BY '${NEW_MYSQL_ROOT_PASSWORD}'\"${password_flag:-}"

	print_status 'Setting the SimpleRisk database password...'
	exec_cmd "sed -i \"s/\(DB_PASSWORD', '\)simplerisk/\1${MYSQL_SIMPLERISK_PASSWORD}/\" /var/www/simplerisk/includes/config.php"
	exec_cmd "sed -i \"s/\(SIMPLERISK_INSTALLED', '\)false/\1true/\" /var/www/simplerisk/includes/config.php"
}

set_php_settings() {
	# $1 receives the path to php settings file
	print_status 'Setting the maximum file upload size in PHP to 5MB and memory limit to 256M...'
	exec_cmd "sed -i 's/\(upload_max_filesize =\) .*/\1 5M/g' $1"
	exec_cmd "sed -i 's/\(memory_limit =\) .*/\1 256M/g' $1"

	print_status 'Setting the maximum input variables in PHP to 3000...'
	exec_cmd "sed -i 's/\(;\|\#\)\?\(max_input_vars =\).*/\2 3000/g' $1"
}

set_up_simplerisk() {
	# $1 receives the user to set the ownership of the simplerisk directory
	# $2 receives current SimpleRisk's version
	print_status 'Downloading the latest SimpleRisk release to /var/www/simplerisk...'
	if [ ! -d /var/www ]; then
		exec_cmd 'mkdir -p /var/www/'
	elif [ -d /var/www/html ]; then
		exec_cmd 'rm -r /var/www/html'
	fi
	exec_cmd "cd /var/www && wget https://simplerisk-downloads.s3.amazonaws.com/public/bundles/simplerisk-${2}.tgz"
	exec_cmd "cd /var/www && tar xvzf simplerisk-${2}.tgz"
	exec_cmd "rm -f /var/www/simplerisk-${2}.tgz"
	exec_cmd "cd /var/www/simplerisk && wget https://github.com/simplerisk/database/raw/master/simplerisk-en-${2}.sql -O database.sql"
	exec_cmd "chown -R ${1}: /var/www/simplerisk"
}

set_up_backup_cronjob() {
	exec_cmd "(crontab -l 2>/dev/null; echo '* * * * * $(which php) -f /var/www/simplerisk/cron/cron.php') | crontab -"
}

get_current_simplerisk_version() {
	curl -sL "https://updates${TESTING:+-test}.simplerisk.com/releases.xml" | grep -oP '<release version=(.*)>' | head -n1 | cut -d '"' -f 2
}

get_installed_php_version() {
	php -v | grep -E '^PHP [[:digit:]]' | awk -F ' ' '{print $2}' | awk -F '.' '{print $NR"."$2}'
}

success_final_message(){
	print_status 'Check /root/passwords.txt for the MySQL root and simplerisk passwords.'
	print_status 'As these passwords are stored in clear text, we recommend immediately moving them into a password manager and deleting this file.'
	print_status 'INSTALLATION COMPLETED SUCCESSFULLY'
}

bail() {
	print_error_message 'The command exited with failure. Verify the command output or run the script in debug mode (-d|--debug).'
}

########################
## INSTALLATION LOGIC ##
########################
setup_ubuntu_debian(){
	export DEBIAN_FRONTEND=noninteractive

	print_status "Running SimpleRisk ${1} installer..."

	print_status 'Populating apt-get cache...'
	exec_cmd 'apt-get update'

	# Add PHP8 for Ubuntu 20|Debian 11
	if [ "${OS}" != "${UBUNTU_OSVAR}" ] || [[ "${VER}" = '20.04' ]]; then
		exec_cmd 'mkdir -p /etc/apt/keyrings'
		local apt_php_version=8.1
		if [ "${OS}" = "${UBUNTU_OSVAR}" ]; then
			print_status "Adding Ondrej's PPA with PHP8"
			exec_cmd 'add-apt-repository -y ppa:ondrej/php'
		else
			print_status 'Install gnupg to handle keyrings...'
			exec_cmd 'apt-get install -y gnupg'

			print_status "Adding Ondrej's repository with PHP8"
			exec_cmd 'wget -qO - https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /etc/apt/keyrings/sury-php.gpg'
			exec_cmd "echo 'deb [signed-by=/etc/apt/keyrings/sury-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main' | sudo tee /etc/apt/sources.list.d/sury-php.list"
		fi

		# Add MySQL 8 for Debian
		if [ "${OS}" = "${DEBIAN_OSVAR}" ]; then
			print_status 'Adding MySQL 8 repository'
			exec_cmd "wget -qO - $MYSQL_KEY_URL | gpg --dearmor -o /etc/apt/keyrings/mysql.gpg"
			exec_cmd "echo 'deb [signed-by=/etc/apt/keyrings/mysql.gpg] https://repo.mysql.com/apt/$(lsb_release -si | tr '[:upper:]' '[:lower:]')/ $(lsb_release -sc) mysql-8.4-lts' | sudo tee /etc/apt/sources.list.d/mysql.list"
		fi

		print_status 'Re-populating apt-get cache with added repos...'
		exec_cmd 'apt-get update'
	fi

	print_status 'Updating current packages (this may take a bit)...'
	exec_cmd 'apt-get dist-upgrade -qq --assume-yes'

	if [ "${OS}" = "${UBUNTU_OSVAR}" ] && [[ "${VER}" != '20.04' ]]; then
		print_status 'Installing lamp-server...'
		exec_cmd 'apt-get install -y lamp-server^'
	else
		print_status 'Installing Apache...'
		exec_cmd 'apt-get install -y apache2'

		print_status 'Installing MySQL...'
		exec_cmd 'apt-get install -y mysql-server'

		print_status 'Installing PHP...'
		exec_cmd "apt-get install -y php${apt_php_version:-} php${apt_php_version:-}-mysql libapache2-mod-php${apt_php_version:-}"

		if [ "${OS}" = "${DEBIAN_OSVAR}" ] && [ "${VER}" = '12' ]; then
			print_status 'Installing crontab for Debian 12'
			exec_cmd 'apt-get install -y cron'
		fi
	fi

	print_status 'Installing PHP development libraries...'
	exec_cmd "apt-get install -y php${apt_php_version:-}-dev"

	for module in xml mbstring mysql ldap curl gd zip intl; do
		print_status "Installing the $module module for PHP..."
		exec_cmd "apt-get install -y php${apt_php_version:-}-$module"
	done

	print_status 'Enabling the ldap module in PHP...'
	exec_cmd 'phpenmod ldap'

	print_status 'Enabling SSL for Apache...'
	exec_cmd 'a2enmod rewrite'
	exec_cmd 'a2enmod ssl'
	exec_cmd 'a2ensite default-ssl'

	print_status 'Installing sendmail...'
	exec_cmd 'apt-get install -y sendmail'

	print_status 'Configuring secure settings for Apache...'
	exec_cmd "sed -i 's/\(SSLProtocol\) all -SSLv3/\1 TLSv1.2/g' /etc/apache2/mods-enabled/ssl.conf"
	exec_cmd "sed -i 's/#\?\(SSLHonorCipherOrder\) on/\1 on/g' /etc/apache2/mods-enabled/ssl.conf"
	exec_cmd "sed -i 's/\(ServerTokens\) OS/\1 Prod/g' /etc/apache2/conf-enabled/security.conf"
	exec_cmd "sed -i 's/\(ServerSignature\) On/\1 Off/g' /etc/apache2/conf-enabled/security.conf"

	# Obtaining php version to find settings file path
	[ -n "${apt_php_version:-}" ] && php_version=$apt_php_version || php_version=$(get_installed_php_version)

	set_php_settings "/etc/php/$php_version/apache2/php.ini"

	set_up_simplerisk 'www-data' "${1}"

	print_status 'Configuring Apache...'
	exec_cmd "sed -i 's|\(/var/www/\)html|\1simplerisk|g' /etc/apache2/sites-enabled/000-default.conf"
	if ! grep -q 'RewriteEngine On' /etc/apache2/sites-enabled/000-default.conf; then
		exec_cmd "sed -i '/^<\/VirtualHost>/i \\\tRewriteEngine On\n\tRewriteCond %{HTTPS} !=on\n\tRewriteRule ^/?(.*) https://%{SERVER_NAME}/\$1 [R,L]' /etc/apache2/sites-enabled/000-default.conf"
	fi
	exec_cmd "sed -i 's|/var/www/html|/var/www/simplerisk|g' /etc/apache2/sites-enabled/default-ssl.conf"
	if ! grep -q 'AllowOverride all' /etc/apache2/sites-enabled/default-ssl.conf; then
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

	print_status 'Restarting MySQL to load the new configuration...'
	exec_cmd 'service mysql restart'

	print_status 'Removing the SimpleRisk database file...'
	exec_cmd 'rm -r /var/www/simplerisk/database.sql'

	print_status 'Setting up Backup cronjob...'
	set_up_backup_cronjob

	if [ "${OS}" = "${DEBIAN_OSVAR}" ]; then
		print_status 'Installing UFW firewall...'
		exec_cmd 'apt-get install -y ufw'
	fi

	print_status 'Enabling UFW firewall...'
	exec_cmd 'ufw allow ssh'
	exec_cmd 'ufw allow http'
	exec_cmd 'ufw allow https'
	exec_cmd 'ufw --force enable'
}

#################
## MAIN SCRIPT ##
#################
main() {
	local current_simplerisk_version
	current_simplerisk_version=$(get_current_simplerisk_version)

	setup_ubuntu_debian "$current_simplerisk_version"
	success_final_message
}

main