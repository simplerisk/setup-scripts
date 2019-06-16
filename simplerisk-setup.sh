#!/bin/bash

###########################################
# SIMPLERISK SETUP SCRIPT FOR UBUNTU 18.04
# Run as root or insert `sudo -E` before `bash`: 
# curl -sL https://raw.githubusercontent.com/simplerisk/setup-scripts/master/simplerisk-setup.sh | bash -
# OR
# wget -qO- https://raw.githubusercontent.com/simplerisk/setup-scripts/master/simplerisk-setup.sh | bash -
###########################################

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
exec_cmd "sed -i '/^;extension=xsl/a extension=mcrypt.so' /etc/php/7.2/apache2/php.ini > /dev/null 2>&1"
exec_cmd "sed -i '/^;extension=xsl/a extension=mcrypt.so' /etc/php/7.2/cli/php.ini > /dev/null 2>&1"

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
exec_cmd "sed -i '/^<\/VirtualHost>/i \\\tRewriteEngine On\n\tRewriteCond %{HTTPS} !=on\n\tRewriteRule ^/?(.*) https://%{SERVER_NAME}/$1 [R,L]' /etc/apache2/sites-enabled/000-default.conf > /dev/null 2>&1"
exec_cmd "sed -i 's/\/var\/www\/html/\/var\/www\/simplerisk/g' /etc/apache2/sites-enabled/default-ssl.conf > /dev/null 2>&1"
exec_cmd "sed -i '/<\/Directory>/a \\\t\t<Directory \"\/var\/www\/simplerisk\">\n\t\t\tAllowOverride all\n\t\t\tallow from all\n\t\t\tOptions -Indexes\n\t\t<\/Directory>' /etc/apache2/sites-enabled/default-ssl.conf > /dev/null 2>&1"

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

setup(){
	# Check to make sure we are running as root
	check_root

	echo "This script will install SimpleRisk on this sytem.  Are you sure that you would like to proceed?"
	read -p "Type \"Yes\" to proceed: " answer < /dev/tty
	case $answer in
		Yes ) os_detect; break;;
		yes ) os_detect; break;;
		y ) os_detect; break;;
	esac
	done
	exit
}

hostname(){
	echo "Would you like to specify a hostname for this SimpleRisk instance?"
	read -p "[ Yes / No ]: " answer < /dev/tty
	case $answer in
		Yes ) get_hostname; break;;
		No ) os_detect; break;;
	esac
	done
}

get_hostname(){
	read -p "Hostname: " hostname < /dev/tty
	os_detect
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

	if [ $OS -eq "Ubuntu" ]; then
		if [ $VER -eq "18.04" ]; then
			echo "Detected that we are running ${OS} ${VER}.  Continuing with SimpleRisk setup."
			setup_ubuntu_1804
		fi
	else
		echo "The SimpleRisk setup script cannot reliably determine which commands to run for this OS.  Exiting."
		exit 1
	fi
}

## Defer setup until we have the complete script
setup
