#!/bin/bash

##Author Sean Mancini
#www.seanmancini.com

##Purpose this script will facilitate the installation of Cacti along with all supporting binaries 
#this script will also ensure that proper configurations are put in place to get up and running with cacti

##Dont forget to checkout cacti @ www.cacti.net

#    This program is free software: you can redistribute it and/or modify#
#    it under the terms of the GNU General Public License as published by#
#    the Free Software Foundation, either version 3 of the License, or#
#    (at your option) any later version.#
#    This program is distributed in the hope that it will be useful,#
#    but WITHOUT ANY WARRANTY; without even the implied warranty of#
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the#
#    GNU General Public License for more details.#
#    You should have received a copy of the GNU General Public License#
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.#






echo "This script will download all Cacti dependecies and download the chosen cacti version from the cacti github"
echo "Dont forget to support cacti @ cacti.net!"



#Download chosen release
echo "here are some of the current cacti release versions \n
release/1.2.3
release/1.2.2
release/1.2.1
release/1.2.0
"

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

##Download required packages for cacti

echo "cacti requires a LAMP stack as well as some required plugins we will now install the required packages"
apt-get update
apt-get  install -y apache2 rrdtool mariadb-server snmp snmpd php7.0 php-mysql  libapache2-mod-php7.0   php7.0-snmp php7.0-xml php7.0-mbstring php7.0-json php7.0-gd php7.0-gmp php7.0-zip php7.0-ldap php7.0-mc




echo "will you be using the spine poller enter 1 for yes 2 for no"
read answer
if [ $answer == "1" ]
then
##Download packages needed for spine
apt-get  install -y build-essential dos2unix dh-autoreconf libtool  help2man libssl-dev libmysql++-dev  librrds-perl libsnmp-dev 
echo "downloading and compling spine"
git clone https://github.com/Cacti/spine.git
cd spine
./bootstrap
./configure
make
make install
chown root:root /usr/local/spine/bin/spine
chmod u+s /usr/local/spine/bin/spine
cd ..

else
echo "spine dependecies  will not be installed"
fi                                                       



##Timezone settings needed for cacti
echo "Enter your PHP time zone i.e America/Toronto  Default is US/Central "
read timezone
if [$timezone == ""] 
then

echo "date.timezone =" US/Central  >> /etc/php/7.0/fpm/php.ini 
echo "date.timezone =" US/Central  >> /etc/php/7.0/cli/php.ini 
echo "date.timezone =" US/Central >> /etc/php/7.0/apache2/php.ini

else


echo "date.timezone =" $timezone >> /etc/php/7.0/fpm/php.ini 
echo "date.timezone =" $timezone >> /etc/php/7.0/cli/php.ini 
echo "date.timezone =" $timezone >> /etc/php/7.0/apache2/php.ini

fi 
#move cacti install to chosen  directory


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
echo "Which user would you like to run Cacti under (Default is www-data) hit enter for default"
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


#assign permissions for cacti installation

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
cp $location/cacti/include/config.php.dist $location/cacti/include/config.php



##Create database 
echo "would you like to customize the database name and user ? hit enter for defaults"
read customize

if [[ $customize = "" ]] 
then

mysql -uroot <<MYSQL_SCRIPT
CREATE DATABASE cacti DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci ;
GRANT ALL PRIVILEGES ON cacti.* TO 'cacti'@'localhost' IDENTIFIED BY 'cacti'; ;
GRANT SELECT ON mysql.time_zone_name TO cacti@localhost;
USE mysql;
ALTER DATABASE cacti CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
FLUSH PRIVILEGES;
MYSQL_SCRIPT

#pre populate cacti db
mysql -u root  cacti < $location/cacti/cacti.sql
mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -u root  mysql

sed -i -e 's@^$database_type.*@$database_type = "mysql";@g' /var/www/html/cacti/include/config.php
sed -i -e 's@^$database_default.*@$database_default = "cacti";@g' /var/www/html/cacti/include/config.php
sed -i -e 's@^$database_hostname.*@$database_hostname = "127.0.0.1";@g' /var/www/html/cacti/include/config.php
sed -i -e 's@^$database_username.*@$database_username = "cacti";@g' /var/www/html/cacti/include/config.php
sed -i -e 's@^$database_password.*@$database_password = "cacti";@g' /var/www/html/cacti/include/config.php
sed -i -e 's@^$database_port.*@$database_port = "3306";@g' /var/www/html/cacti/include/config.php
sed -i -e 's@^$database_ssl.*@$database_ssl = "false";@g' /var/www/html/cacti/include/config.php
sed -i -e 's@^//$url_path@$url_path@g' /var/www/html/cacti/include/config.php





echo "default database setup with following details"
echo "database name cacti\n
database username cacti\n
database password cacti"






else

echo "enter db name"
read customdbname
echo "enter db user"
read customdbuser
echo "enter db password"
read customdbpassword



mysql -u root <<MYSQL_SCRIPT
CREATE DATABASE $customdbname;
GRANT ALL PRIVILEGES ON $customdbname.* TO '$customdbuser'@'localhost' IDENTIFIED BY '$customdbpassword';
GRANT SELECT ON mysql.time_zone_name TO $customdbuser@localhost;
ALTER DATABASE $customdbname CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
FLUSH PRIVILEGES;
MYSQL_SCRIPT

echo "Pre-populating cacti DB"
mysql -u root  $customdbname < $location/cacti/cacti.sql
mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -u root  mysql





sed -i -e 's@^$database_type.*@$database_type = "mysql";@g' $location/cacti/include/config.php
sed -i -e 's@^$database_default.*@$database_default = '$customdbname'\;@g' $location/cacti/include/config.php
sed -i -e 's@^$database_hostname.*@$database_hostname = "127.0.0.1";@g' $location/cacti/include/config.php
sed -i -e 's@^$database_username.*@$database_username = '$customdbuser';@g' $location/cacti/include/config.php
sed -i -e 's@^$database_password.*@$database_password = '$customdbpassword';@g' $location/cacti/include/config.php
sed -i -e 's@^$database_port.*@$database_port = "3306";@g' "$location"/cacti/include/config.php
sed -i -e 's@^$database_ssl.*@$database_ssl = "false";@g' "$location"/cacti/include/config.php
sed -i -e 's@^//$url_path@$url_path@g' $location/cacti/include/config.php







fi
##Adding Maria DB conf 
echo "innodb_flush_log_at_timeout = 4" >>  /etc/mysql/mariadb.conf.d/50-server.cnf
echo "innodb_read_io_threads = 34"   >>  /etc/mysql/mariadb.conf.d/50-server.cnf
echo "innodb_write_io_threads = 17" >> /etc/mysql/mariadb.conf.d/50-server.cnf
echo "max_heap_table_size = 70M"    >>  /etc/mysql/mariadb.conf.d/50-server.cnf
echo "tmp_table_size = 70M"         >>  /etc/mysql/mariadb.conf.d/50-server.cnf
echo "join_buffer_size = 130M" >>  /etc/mysql/mariadb.conf.d/50-server.cnf
echo "innodb_buffer_pool_size = 250M" >>  /etc/mysql/mariadb.conf.d/50-server.cnf
echo "innodb_io_capacity = 5000" >>  /etc/mysql/mariadb.conf.d/50-server.cnf
echo "innodb_io_capacity_max = 10000" >>  /etc/mysql/mariadb.conf.d/50-server.cnf
echo "innodb_file_format = Barracuda" >>  /etc/mysql/mariadb.conf.d/50-server.cnf
echo "innodb_large_prefix = 1" >>  /etc/mysql/mariadb.conf.d/50-server.cnf



###Adding recomended PHP settings 
sed -e 's/max_execution_time = 30/max_execution_time = 60/' -i /etc/php/7.0/apache2/php.ini
sed -e 's/memory_limit = 128M/memory_limit = 400M/' -i /etc/php/7.0/apache2/php.ini




echo "this script can download the following plugins monitor,thold would you like to install them  ?
type yes to download hit enter to skip"
read plugins
 if [ $plugins == "yes" ]
  then
   git clone https://github.com/Cacti/plugin_thold.git
    git clone https://github.com/Cacti/plugin_monitor.git

mv plugin_thold thold
  mv plugin_monitor monitor
   chown -R $user:$user thold
    chown -R $user:$user monitor
     mv thold $location/cacti/plugins
      mv monitor $location/cacti/plugins




else
 echo "plugins will not be installed"
  fi



echo "Would you like to download my RRD Monitoring script ? type yes to download hit enter to skip "
read mon_script
if [ $mon_script == "yes" ]
  then
  git clone  https://github.com/bmfmancini/rrd-monitor.git
      else
       echo "Script will not be downloaded"


####Create cron for cacti user

touch /etc/cron.d/$user
echo "*/5 * * * * $user php $location/cacti/poller.php > /dev/null 2>&1" > /etc/cron.d/$user 








echo "restarting Mysqldb and Apache server for service refresh"
 systemctl restart mysql
  systemctl restart apache2








echo "Cacti installation complete !"


