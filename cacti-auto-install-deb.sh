#!/bin/bash


echo "This script will download all Cacti dependecies and download the chosen cacti version from the cacti github"
echo "Dont forget to support cacti @ cacti.net!"


#Download chosen release

echo  "which release would you like to download ? Hit enter for latest"
read version

if  ["$version" == ""]
then
git clone https://github.com/Cacti/cacti.git


else 
wget https://github.com/Cacti/cacti/archive/release/$version.zip
unzip $version 
mv cacti-release-$version cacti
fi

echo "cacti requires a LAMP stack as well as some required plugins we will now install the required packages"
apt-get update
apt-get  install -y php7.0 php7.0-snmp php7.0-xml php7.0-mbstring php7.0-json php7.0-gd php7.0-gmp php7.0-zip php7.0-ldap php7.0-mcrypt apache2 mariadb-server rrdtool snmp 



echo "will you be using the spine poller enter 1 for yes 2 for no"
read answer
if [$answer == "1"]
then
apt-get  install -y build-essential dos2unix dh-autoreconf help2man libssl-dev libmysql++-dev  librrds-perl libsnmp-dev libmysqlclient-dev libmysqld-dev
else
echo "spine dependecies  will not be installed"
fi

#Specify user password and run mysql_secure_installation Credit goes to  https://stackoverflow.com/questions/24270733/automate-mysql-secure-installation-with-echo-command-via-a-shell-script

echo "specify a root password for mysql root user"
read dbpwd

# Make sure that NOBODY can access the server without a password
mysql -e "UPDATE mysql.user SET Password = PASSWORD (' \$dbpwd\ ') WHERE User = 'root'"
# Kill the anonymous users
mysql -e "DROP USER ''@'localhost'"
# Because our hostname varies we'll use some Bash magic here.
mysql -e "DROP USER ''@'$(hostname)'"
# Kill off the demo database
mysql -e "DROP DATABASE test"
# Make our changes take effect
mysql -e "FLUSH PRIVILEGES"
# Any subsequent tries to run queries this way will get access denied because lack of usr/pwd param



#Create mysql db
echo "enter the name for the cactidb default is cactiuser"
read name
echo "enter database password default is cacti"
read password
if [name == "" ]
then
mysql -uroot -p $pwd -e "CREATE DATABASE cacti"
mysql -uroot -p $pwd -e "GRANT ALL PRIVILEGES ON cacti.* TO $MAINDB@localhost IDENTIFIED BY 'cacti'"
else 
echo "hello"
fi


echo "Enter your PHP time zone i.e America/Toronto "
read timezone
echo "date.timezone =" $timezone >> /etc/php/7.0/fpm/php.ini 
echo "date.timezone =" $timezone >> /etc/php/7.0/cli/php.ini 



#Create cacti user and change permission of directory
echo "Which user would you like to run Cacti under (Default is www-data)"
read user
if [$user == ""]
then  
echo  "cacti will be run under www-data"
chown -R www-data:www-data cacti
else 
useradd $user
chown -R $user:$user
fi



##Move cacti directory  to final place
echo "Where would you like to install cacti default location is /var/www/html hit enter for default location"
read location
if [$location == ""]
then
mv cacti /var/www/html
else
mv cacti $location
fi

