CURRENT_SIMPLERISK_VERSION="20190331-001"

echo "Updating to the latest packages..."
apt-get update -qq
apt-get dist-upgrade -qq

echo "Installing new packages..."
apt-get -y install apache2 php php-mysql php-json mysql-client php-dev libmcrypt-dev php-pear php-ldap php7.2-mbstring
pecl channel-update pecl.php.net
yes '' | pecl install mcrypt-1.0.1

echo "Enabling the mcrypt extension in PHP..."
sed -i '/^;extension=xsl/a extension=mcrypt.so' /etc/php/7.2/apache2/php.ini
sed -i '/^;extension=xsl/a extension=mcrypt.so' /etc/php/7.2/cli/php.ini

echo "Enabling the ldap module in PHP..."
phpenmod ldap

echo "Enabling SSL for Apache..."
a2enmod rewrite
a2enmod ssl
a2ensite default-ssl

echo "Configuring secure settings for Apache..."
sed -i 's/SSLProtocol all -SSLv3/SSLProtocol TLSv1.2/g' /etc/apache2/mods-enabled/ssl.conf
sed -i 's/#SSLHonorCipherOrder on/SSLHonorCipherOrder on/g' /etc/apache2/mods-enabled/ssl.conf
sed -i 's/ServerTokens OS/ServerTokens Prod/g' /etc/apache2/conf-enabled/security.conf
sed -i 's/ServerSignature On/ServerSignature Off/g' /etc/apache2/conf-enabled/security.conf

echo "Setting the maximum file upload size in PHP to 5MB..."
sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 5M/g' /etc/php/7.2/apache2/php.ini

echo "Restarting Apache to reload the new configuration..."
service apache2 restart

echo "Downloading the latest SimpleRisk release..."
cd /var/www/html
wget https://github.com/simplerisk/bundles/raw/master/simplerisk-$CURRENT_SIMPLERISK_VERSION.tgz
tar xvzf simplerisk-$CURRENT_SIMPLERISK_VERSION.tgz
rm simplerisk-$CURRENT_SIMPLERISK_VERSION.tgz
cd simplerisk
wget https://github.com/simplerisk/installer/raw/master/simplerisk-installer-$CURRENT_SIMPLERISK_VERSION.tgz
tar xvzf simplerisk-installer-$CURRENT_SIMPLERISK_VERSION.tgz
rm simplerisk-installer-$CURRENT_SIMPLERISK_VERSION.tgz

echo "Enabling UFW firewall..."
ufw allow ssh
ufw allow http
ufw allow https
ufw enable
