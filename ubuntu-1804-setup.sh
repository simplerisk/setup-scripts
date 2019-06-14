#!/bin/bash

###########################################
# SIMPLERISK SETUP SCRIPT FOR UBUNTU 18.04
# Run as root or insert `sudo -E` before `bash`: 
# curl -sL https://raw.githubusercontent.com/simplerisk/setup-scripts/master/ubuntu-1804-setup.sh | bash -
# OR
# wget -qO- https://raw.githubusercontent.com/simplerisk/setup-scripts/master/ubuntu-1804-setup.sh | bash -
###########################################

CURRENT_SIMPLERISK_VERSION="20190331-001"

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

print_status "Populating apt-get cache..."
exec_cmd 'apt-get update > /dev/null 2>&1'

print_status "Installing tasksel..."
exec_cmd "apt-get install -y tasksel > /dev/null 2>&1"

print_status "Installing lamp-server..."
exec_cmd "tasksel install lamp-server > /dev/null 2>&1"

print_status "Installing mbstring module for PHP..."
exec_cmd "apt-get install -y php-mbstring > /dev/null 2>&1"

print_status "Installing ldap module for PHP..."
exec_cmd "apt-get install -y php-ldap > /dev/null 2>&1"

print_status "Installing pear for PHP..."
exec_cmd "apt-get install -y php-pear php-dev libmcrypt-dev > /dev/null 2>&1"

print_status "Updating pear for PHP..."
exec_cmd "pecl channel-update pecl.php.net > /dev/null 2>&1"

print_status "Installing mcrypt module for PHP..."
exec_cmd "pecl install mcrypt-1.0.1 > /dev/null 2>&1"

#echo "Updating the latest packages..."
#unset UCF_FORCE_CONFFOLD
#export UCF_FORCE_CONFFNEW=YES
#ucf --purge /var/run/grub/menu.lst
#apt-get update -qq
#echo y | apt-get dist-upgrade -qq --force-yes

#echo "Installing the 
#echo "Installing new packages..."
#apt-get -y install apache2 php php-mysql php-json mysql-client php-dev libmcrypt-dev php-pear php-ldap php7.2-mbstring
#pecl channel-update pecl.php.net
#yes '' | pecl install mcrypt-1.0.1

#echo "Enabling the mcrypt extension in PHP..."
#sed -i '/^;extension=xsl/a extension=mcrypt.so' /etc/php/7.2/apache2/php.ini
#sed -i '/^;extension=xsl/a extension=mcrypt.so' /etc/php/7.2/cli/php.ini

#echo "Enabling the ldap module in PHP..."
#phpenmod ldap

#echo "Enabling SSL for Apache..."
#a2enmod rewrite
#a2enmod ssl
#a2ensite default-ssl

#echo "Configuring secure settings for Apache..."
#sed -i 's/SSLProtocol all -SSLv3/SSLProtocol TLSv1.2/g' /etc/apache2/mods-enabled/ssl.conf
#sed -i 's/#SSLHonorCipherOrder on/SSLHonorCipherOrder on/g' /etc/apache2/mods-enabled/ssl.conf
#sed -i 's/ServerTokens OS/ServerTokens Prod/g' /etc/apache2/conf-enabled/security.conf
#sed -i 's/ServerSignature On/ServerSignature Off/g' /etc/apache2/conf-enabled/security.conf

#echo "Setting the maximum file upload size in PHP to 5MB..."
#sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 5M/g' /etc/php/7.2/apache2/php.ini

#echo "Restarting Apache to reload the new configuration..."
#service apache2 restart

#echo "Downloading the latest SimpleRisk release..."
#cd /var/www/html
#wget https://github.com/simplerisk/bundles/raw/master/simplerisk-$CURRENT_SIMPLERISK_VERSION.tgz
#tar xvzf simplerisk-$CURRENT_SIMPLERISK_VERSION.tgz
#rm simplerisk-$CURRENT_SIMPLERISK_VERSION.tgz
#cd simplerisk
#wget https://github.com/simplerisk/installer/raw/master/simplerisk-installer-$CURRENT_SIMPLERISK_VERSION.tgz
#tar xvzf simplerisk-installer-$CURRENT_SIMPLERISK_VERSION.tgz
#rm simplerisk-installer-$CURRENT_SIMPLERISK_VERSION.tgz

#echo "Enabling UFW firewall..."
#ufw allow ssh
#ufw allow http
#ufw allow https
#echo "y" | ufw enable

}

## Defer setup until we have the complete script
setup
