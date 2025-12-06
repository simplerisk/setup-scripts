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
	# CentOS 7, RHEL 9: /var/log/mysqld.log
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
setup_centos_rhel(){
	print_status "Running SimpleRisk ${1} installer..."

	# If OS is CentOS, use yum. Else (RHEL or CentOS Stream), use dnf.
	[ "${OS}" = 'CentOS Linux' ] && pkg_manager='yum' || pkg_manager='dnf'

	print_status "Updating packages with $pkg_manager. This may take some time."
	exec_cmd "$pkg_manager -y update"

	print_status 'Installing the wget package...'
	exec_cmd "$pkg_manager -y install wget"

	print_status 'Installing Firewalld...'
	exec_cmd "$pkg_manager -y install firewalld"

	print_status 'Enabling MySQL 8 repositories...'
	exec_cmd "rpm --import $MYSQL_KEY_URL"
	case ${VER:0:1} in
		8) exec_cmd 'rpm -Uvh https://dev.mysql.com/get/mysql84-community-release-el8-1.noarch.rpm';;
		9) exec_cmd 'rpm -Uvh https://dev.mysql.com/get/mysql84-community-release-el9-1.noarch.rpm';;
	esac

	print_status 'Enabling PHP 8 repositories...'
	exec_cmd "$pkg_manager -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-${VER:0:1}.noarch.rpm"
	case ${VER:0:1} in
		8) exec_cmd "rpm --import https://rpms.remirepo.net/RPM-GPG-KEY-remi2018";;
		9) exec_cmd "rpm --import https://rpms.remirepo.net/RPM-GPG-KEY-remi2021";;
	esac
	exec_cmd "$pkg_manager -y install https://rpms.remirepo.net/enterprise/remi-release-${VER:0:1}.rpm"
	exec_cmd "$pkg_manager -y update"


	print_status 'Installing PHP for Apache...'
	if [ "${OS}" = 'CentOS Linux' ]; then
		exec_cmd "$pkg_manager -y --enablerepo=remi,remi-php81 install httpd php php-common"
		exec_cmd "$pkg_manager -y --enablerepo=remi,remi-php81 install php-cli php-pdo php-mysqlnd php-gd php-zip php-mbstring php-xml php-curl php-ldap php-json php-intl php-posix"
	else
		exec_cmd "$pkg_manager -y module reset php"
		exec_cmd "$pkg_manager -y module enable php:remi-8.1"
		exec_cmd "$pkg_manager -y install httpd php php-common php-mysqlnd php-mbstring php-opcache php-gd php-zip php-json php-ldap php-curl php-xml php-intl php-process"
	fi

	set_php_settings /etc/php.ini

	print_status 'Installing the MySQL database server...'
	exec_cmd "$pkg_manager install -y mysql-server"

	print_status 'Enabling and starting MySQL database server...'
	exec_cmd 'systemctl enable mysqld'
	exec_cmd 'systemctl start mysqld'

	if [[ "${VER}" = 8* ]]; then
		exec_cmd "$pkg_manager clean all"
		exec_cmd 'rm -rf /var/cache/dnf/remi-*a'
		exec_cmd "$pkg_manager -y update"
	fi

	print_status 'Installing mod_ssl'
	exec_cmd "$pkg_manager -y install mod_ssl"

	print_status 'Installing sendmail'
	exec_cmd "$pkg_manager -y install sendmail sendmail-cf m4"

	set_up_simplerisk 'apache' "${1}"

	print_status 'Configuring Apache...'
	if [[ "${OS}" != 'CentOS Linux' ]]; then
		exec_cmd "sed -i 's|#\?\(DocumentRoot \"/var/www/\)html\"|\1simplerisk\"|' /etc/httpd/conf.d/ssl.conf"
		exec_cmd 'rm /etc/httpd/conf.d/welcome.conf'
	fi
	exec_cmd 'mkdir /etc/httpd/sites-{available,enabled}'
	exec_cmd "sed -i 's|\(DocumentRoot \"/var/www\).*|\1\"|g' /etc/httpd/conf/httpd.conf"
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
		else
			set_up_database
		fi
	fi

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
	value_one_permissions=('httpd_builtin_scripting' 'httpd_can_network_connect' 'httpd_can_sendmail' 'httpd_dbus_avahi' 'httpd_enable_cgi' 'httpd_read_user_content' 'httpd_tty_comm')
	for permission in "${value_one_permissions[@]}"; do
		exec_cmd "setsebool -P $permission=1"
	done
	value_nil_permissions=('allow_httpd_anon_write' 'allow_httpd_mod_auth_ntlm_winbind' 'allow_httpd_mod_auth_pam' 'allow_httpd_sys_script_anon_write' 'httpd_can_check_spam' 'httpd_can_network_connect_cobbler' 'httpd_can_network_connect_db' 'httpd_can_network_memcache' 'httpd_can_network_relay' 'httpd_dbus_sssd' 'httpd_enable_ftp_server' 'httpd_enable_homedirs' 'httpd_execmem' 'httpd_manage_ipa' 'httpd_run_preupgrade' 'httpd_run_stickshift' 'httpd_serve_cobbler_files' 'httpd_setrlimit' 'httpd_ssi_exec' 'httpd_tmp_exec' 'httpd_use_cifs' 'httpd_use_fusefs' 'httpd_use_gpg' 'httpd_use_nfs' 'httpd_use_openstack' 'httpd_verify_dns')
	for permission in "${value_nil_permissions[@]}"; do
		exec_cmd "setsebool -P $permission=0"
	done
	exec_cmd 'chcon -R -t httpd_sys_rw_content_t /var/www/simplerisk'
}

#################
## MAIN SCRIPT ##
#################
main() {
	# SIMPLERISK_VERSION is passed from the main setup script
	if [ -z "${SIMPLERISK_VERSION:-}" ]; then
		print_error_message "SIMPLERISK_VERSION environment variable not set. This script should be called from the main setup script."
	fi

	setup_centos_rhel "$SIMPLERISK_VERSION"
	success_final_message
}

main