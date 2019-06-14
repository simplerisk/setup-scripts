#!/bin/bash

###########################################
# SIMPLERISK SETUP SCRIPT FOR UBUNTU 18.04
# Run as root or insert `sudo -E` before `bash`: 
# curl -sL https://raw.githubusercontent.com/simplerisk/setup-scripts/master/ubuntu-1804-setup.sh | bash -
# OR
# wget -qO- https://raw.githubusercontent.com/simplerisk/setup-scripts/master/ubuntu-1804-setup.sh | bash -
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

setup(){

# Get the current SimpleRisk release version
CURRENT_SIMPLERISK_VERSION=`curl -sL https://updates.simplerisk.com/Current_Version.xml | grep -oP '<appversion>(.*)</appversion>' | cut -d '>' -f 2 | cut -d '<' -f 1`

print_status "Running SimpleRisk ${CURRENT_SIMPLERISK_VERSION} installer..."

print_status "Populating apt-get cache..."
exec_cmd 'apt-get update > /dev/null 2>&1'

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

print_status "Restarting Apache to reload the new configuration..."
exec_cmd "service apache2 restart > /dev/null 2>&1"

print_status "Downloading the latest SimpleRisk release to /var/www/simplerisk..."
exec_cmd "cd /var/www > /dev/null 2>&1"
exec_cmd "rm -r html > /dev/null 2>&1"
exec_cmd "wget https://github.com/simplerisk/bundles/raw/master/simplerisk-${CURRENT_SIMPLERISK_VERSION}.tgz > /dev/null 2>&1"
exec_cmd "tar xvzf simplerisk-${CURRENT_SIMPLERISK_VERSION}.tgz > /dev/null 2>&1"
exec_cmd "rm simplerisk-${CURRENT_SIMPLERISK_VERSION}.tgz
exec_cmd "cd simplerisk > /dev/null 2>&1"
exec_cmd "wget https://github.com/simplerisk/installer/raw/master/simplerisk-installer-${CURRENT_SIMPLERISK_VERSION}.tgz > /dev/null 2>&1"
exec_cmd "tar xvzf simplerisk-installer-${CURRENT_SIMPLERISK_VERSION}.tgz > /dev/null 2>&1"
exec_cmd "rm simplerisk-installer-${CURRENT_SIMPLERISK_VERSION}.tgz > /dev/null 2>&1"

print_status "Enabling UFW firewall..."
exec_cmd "ufw allow ssh > /dev/null 2>&1"
exec_cmd "ufw allow http > /dev/null 2>&1"
exec_cmd "ufw allow https > /dev/null 2>&1"
exec_cmd "ufw --force enable > /dev/null 2>&1"

#echo "Updating the latest packages..."
#unset UCF_FORCE_CONFFOLD
#export UCF_FORCE_CONFFNEW=YES
#ucf --purge /var/run/grub/menu.lst
#apt-get update -qq
#echo y | apt-get dist-upgrade -qq --force-yes

#echo "Installing the
#echo "Installing new packages..."
#apt-get -y install apache2 php php-mysql php-json mysql-client php-dev libmcrypt-dev php-pear php-ldap php7.2-mbstring

}

## Defer setup until we have the complete script
setup
