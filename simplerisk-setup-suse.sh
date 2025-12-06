#!/usr/bin/env bash

set -euo pipefail

readonly MYSQL_KEY_URL='https://repo.mysql.com/RPM-GPG-KEY-mysql-2023'

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
	# $1 should receive the mysqld.log path to retrieve password:
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
setup_suse(){
	print_status "Running SimpleRisk ${1} installer..."

	print_status 'Populating zypper cache...'
	exec_cmd 'zypper -n update'

	if ! rpm -q mysql84-community-release; then
		print_status 'Adding MySQL 8 repository...'
		exec_cmd 'rpm -Uvh https://dev.mysql.com/get/mysql84-community-release-sl15-1.noarch.rpm'
		exec_cmd "rpm --import $MYSQL_KEY_URL"
	fi

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
	exec_cmd 'zypper -n install php8 php8-mysql apache2-mod_php8 php8-ldap php8-curl php8-zlib php8-phar php8-mbstring php8-intl php8-posix php8-gd php8-zip php-xml'
	exec_cmd 'a2enmod php8'

	print_status 'Enabling SSL for Apache...'
	for module in rewrite ssl mod_ssl; do
		exec_cmd "a2enmod $module"
	done

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
	RewriteRule ^/?(.*) https://%{SERVER_NAME}/\$1 [R,L]
</VirtualHost>
EOF

	generate_passwords

	# Generate the OpenSSL private key
	exec_cmd 'openssl rand -hex 50 > /tmp/pass_openssl.txt'
	exec_cmd 'openssl genrsa -des3 -passout file:/tmp/pass_openssl.txt -out /etc/apache2/ssl.key/simplerisk.pass.key'
	exec_cmd 'openssl rsa -passin file:/tmp/pass_openssl.txt -in /etc/apache2/ssl.key/simplerisk.pass.key -out /etc/apache2/ssl.key/simplerisk.key'

	# Remove the original key file
	exec_cmd 'rm /etc/apache2/ssl.key/simplerisk.pass.key /tmp/pass_openssl.txt'

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
	exec_cmd "sed -i 's/#\?\(SSLHonorCipherOrder\)/\1/g' /etc/apache2/ssl-global.conf"

	set_php_settings /etc/php8/apache2/php.ini

	print_status 'Specifying the MySQL socket path...'
	for extension in mysqli pdo_mysql; do
		exec_cmd "sed -i 's|\($extension.default_socket\).*|\1=/var/lib/mysql/mysql.sock|' /etc/php8/apache2/php.ini"
	done

	set_up_simplerisk 'wwwrun' "${1}"

	print_status 'Restarting Apache to load the new configuration...'
	exec_cmd 'systemctl restart apache2'

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

#################
## MAIN SCRIPT ##
#################
main() {
	local current_simplerisk_version
	current_simplerisk_version=$(get_current_simplerisk_version)

	setup_suse "$current_simplerisk_version"
	success_final_message
}

main