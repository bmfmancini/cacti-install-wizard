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
apt-get  install -y apache2 rrdtool mariadb-server snmp snmpd php7.0 php7.0-snmp php7.0-xml php7.0-mbstring php7.0-json php7.0-gd php7.0-gmp php7.0-zip php7.0-ldap php7.0-mc




echo "will you be using the spine poller enter 1 for yes 2 for no"
read answer
if [$answer == "1"]
then
apt-get  install -y build-essential dos2unix dh-autoreconf help2man libssl-dev libmysql++-dev  librrds-perl libsnmp-dev libmysqlcli$
else
echo "spine dependecies  will not be installed"
fi                                                       




echo "Enter your PHP time zone i.e America/Toronto "
read timezone
echo "date.timezone =" $timezone >> /etc/php/7.0/fpm/php.ini 
echo "date.timezone =" $timezone >> /etc/php/7.0/cli/php.ini 




#move cacti install to chose directory

echo "Where would you like to install cacti default location is /var/www/html hit enter for default location"
read location
if [$location == ""]
then

location="/var/www/html"

mv cacti /var/www/html
else
mv cacti $location
fi


#Create cacti user and change permission of directory
echo "Which user would you like to run Cacti under (Default is www-data)"
read user
if [$user == ""]
then 
user="www-data"
echo  "cacti will be run under www-data"
chown -R  www-data:www-data $location/cacti
else 
useradd $user
chown -R $user:$user $location/cacti
fi


#assign permissions

chown -R $user.$user $location/cacti/resource/snmp_queries/          
chown -R $user.$user $location/cacti/resource/script_server/
chown -R $user.$user $location/cacti/resource/script_queries/
chown -R $user.$user $location/cacti/scripts/
chown -R $user.$user $location/cacti/cache/boost/
chown -R $user.$user $location/cacti/cache/mibcache/
chown -R $user.$user $location/cacti/cache/realtime/
chown -R $user.$user $location/cacti/cache/spikekill/
touch $location/cacti/log/cacti.log
chmod 777 $location/cacti/log/cacti.log
chown -R $user.$user $location/cacti/log/
