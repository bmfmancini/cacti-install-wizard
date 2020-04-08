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


echo "this script requires git"
apt-get install git unzip -y



echo "This script will download all Cacti dependecies and download the chosen cacti version from the cacti github"
echo "Dont forget to support cacti @ cacti.net!"


function new_install () {


#Download chosen release

echo "here are some of the current cacti release versions \n"
 git ls-remote --tags https://github.com/Cacti/cacti|grep 'release/[[:digit:]\.]*$'|tail -10|awk '{print $2}'|tr 'refs/tags/release' ' '|sed 's/^ *//;s/ *$//'


###One day I will have this auto populate 


echo  "which release would you like to download ? Hit enter for latest"
read version

if  [ "$version" == "" ]
then
git clone -b 1.2.x https://github.com/Cacti/cacti.git


else 
wget https://github.com/Cacti/cacti/archive/release/$version.zip
unzip $version 
mv cacti-release-$version cacti
fi

##Download required packages for cacti

echo "cacti requires a LAMP stack as well as some required plugins we will now install the required packages"
apt-get update
apt-get  install -y apache2 libapache2-mod-php  rrdtool mariadb-server snmp snmpd php php-mysql  libapache2-mod-php   php-snmp php-xml php-mbstring php-json php-gd php-gmp php-zip php-ldap 




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


###Find installed version of PHP

php_version="$(php -v | head -n 1 | cut -d " "  -f 2 | cut -f1-2 -d".")"



##Timezone settings needed for cacti
echo "Enter your PHP time zone i.e America/Toronto  Default is US/Central "
read timezone
if [$timezone = ""] 
then

echo "date.timezone =" US/Central  >> /etc/php/$php_version/cli/php.ini 
echo "date.timezone =" US/Central >> /etc/php/$php_version/apache2/php.ini

else


echo "date.timezone =" $timezone >> /etc/php/$php_version/cli/php.ini 
echo "date.timezone =" $timezone >> /etc/php/$php_version/apache2/php.ini

fi 
#move cacti install to chosen  directory


echo "Where would you like to install cacti default location is /var/www/html hit enter for default location"
read location
if [$location = ""]
then

location="/var/www/html"

mv cacti /var/www/html
else
mv cacti $location
fi


#Create cacti user and change permission of directory
echo "Which user would you like to run Cacti under (Default is www-data) hit enter for default"
read user
if [$user = ""]
then 
user="www-data"
echo  "cacti will be run under $user"
chown -R  $user:$user $location/cacti
else 
useradd $user
chown -R $user:$user $location/cacti
###Create cron entry for new user 

fi

##Create  cron entry 
touch /etc/cron.d/$user
echo "*/5 * * * * $user php $location/cacti/poller.php > /dev/null 2>&1" > /etc/cron.d/$user 



#assign permissions for cacti installation to www-data user
chown -R www-data:www-data $location/cacti/resource/snmp_queries/          
chown -R www-data:www-data $location/cacti/resource/script_server/
chown -R www-data:www-data $location/cacti/resource/script_queries/
chown -R www-data:www-data $location/cacti/scripts/
chown -R www-data:www-data $location/cacti/cache/boost/
chown -R www-data:www-data $location/cacti/cache/mibcache/
chown -R www-data:www-data $location/cacti/cache/realtime/
chown -R www-data:www-data $location/cacti/cache/spikekill/
touch $location/cacti/log/cacti.log
chmod 664 $location/cacti/log/cacti.log
chown -R www-data:www-data  $location/cacti/log/
cp $location/cacti/include/config.php.dist $location/cacti/include/config.php





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


systemctl restart mysql



##Create database 
echo "would you like to customize the database name and user ? hit enter for defaults"
read customize

if [[ $customize = "" ]] 
then

password="$(openssl rand -base64 32)"

mysql -uroot <<MYSQL_SCRIPT
CREATE DATABASE cacti DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci ;
GRANT ALL PRIVILEGES ON cacti.* TO 'cacti'@'localhost' IDENTIFIED BY '$password'; ;
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
##sed -i -e 's@^$database_password.*@$database_password = "cacti";@g' /var/www/html/cacti/include/config.php
sed -i -e 's@^$database_password.*@$database_password = "'$password'";@g' /var/www/html/cacti/include/config.php
sed -i -e 's@^$database_port.*@$database_port = "3306";@g' /var/www/html/cacti/include/config.php
sed -i -e 's@^$database_ssl.*@$database_ssl = "false";@g' /var/www/html/cacti/include/config.php
sed -i -e 's@^//$url_path@$url_path@g' /var/www/html/cacti/include/config.php






echo "
default database setup with following details
database name cacti
database username cacti
datbase password  $password 
"





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



###Adding recomended PHP settings 
sed -e 's/max_execution_time = 30/max_execution_time = 60/' -i /etc/php/$php_version/apache2/php.ini
sed -e 's/memory_limit = 128M/memory_limit = 400M/' -i /etc/php/$php_version/apache2/php.ini




echo "this script can download the following plugins monitor,thold,audit from the cacti group  would you like to install them  ? type yes to download hit enter to skip"
read plugins
 if [[  $plugins == "yes"  ]]
  then
   git clone https://github.com/Cacti/plugin_thold.git  thold
    git clone https://github.com/Cacti/plugin_monitor.git monitor
    git clone https://github.com/Cacti/plugin_audit.git audit


   chown -R $user:$user thold
    chown -R $user:$user monitor
     chown -R $user:$user audit
     mv thold $location/cacti/plugins
      mv monitor $location/cacti/plugins
       mv monitor $location/cacti/plugins




else
 echo "plugins will not be installed"
  fi



echo "Would you like to download my RRD Monitoring script ? type yes to download hit enter to skip "
read mon_script
if [[ $mon_script == "yes" ]]
  then
  git clone  https://github.com/bmfmancini/rrd-monitor.git
      else
       echo "Script will not be downloaded"
fi

####Create cron for cacti user

touch /etc/cron.d/$user
echo "*/5 * * * * $user php $location/cacti/poller.php > /dev/null 2>&1" > /etc/cron.d/$user 








echo "restarting Mysqldb and Apache server for service refresh"
systemctl restart mysql
systemctl restart apache2








echo "Cacti installation complete !"


}



function spine_install () {


##Download packages needed for spine
apt-get  install -y build-essential dos2unix dh-autoreconf libtool  help2man libssl-dev     librrds-perl libsnmp-dev 
apt-get install -y libmysql++-dev ##For debian 9 and below
apt-get install -y default-libmysqlclient-dev ###For debian 10+

echo " Which version of spine would you like to use ? Hit enter for the latest or enter the release vesrion i.e 1.2.3 Usually should Match your installed version of Cacti"
read version

if [$version = ""]
then

echo "downloadinglatest version of spine  and compling "
git clone https://github.com/Cacti/spine.git
cd spine
./bootstrap
./configure
make
make install
chown root:root /usr/local/spine/bin/spine
chmod u+s /usr/local/spine/bin/spine

else

wget https://github.com/Cacti/spine/archive/release/$version.zip
unzip $version.zip
cd spine-release-$version
./bootstrap
./configure
make
make install
chown root:root /usr/local/spine/bin/spine
chmod u+s /usr/local/spine/bin/spine

fi

cp /usr/local/spine/etc/spine.conf.dist  /usr/local/spine/etc/spine.conf



echo "Spine has been compiled and installed you will now need to configure your DB credentials to /usr/local/spine/etc/spine.conf"

echo "Would you like to configure you spine.conf file? y or n"
read answer
if [ $answer == "y" ]
then
echo "Enter database user"
read user
echo "enter database password"
read password
echo "enter database name"
read databasename

sed -i -e 's@^DB_Host.*@DB_Host  127.0.0.1@g' /usr/local/spine/etc/spine.conf
sed -i -e 's@^DB_User.*@DB_User  '$user'@g' /usr/local/spine/etc/spine.conf
sed -i -e 's@^DB_Pass.*@DB_Pass  '$password'@g' /usr/local/spine/etc/spine.conf
sed -i -e 's@^DB_Database.*@DB_Database  '$databasename'@g' /usr/local/spine/etc/spine.conf

else


echo "spine install completed"

fi

}


function cacti_upgrade () {

echo "Stopping cron service"
systemctl stop cron


echo "this option will upgrade you existing cacti installation
you will need to supply you db information and cacti installation path"

echo "specify your db username"
read currentdbuser

echo "specify your database name"
read currentdb
echo "specify your current db password"
read currentdbpwd
echo "specify your cacti install path usually /var/www/html hit enter to accept default"
read currentpath
if [  "$currentpath" == "" ]
then 
currentpath="/var/www/html"
fi

echo "backing up DB"
mysqldump -u $currentdbuser -p $currentdbpassword + " " $currentdb > cacti_db_backup.sql



echo  "which release would you like to upgrade to? Hit enter for latest"
read version

if  [ "$version" == "" ]
then
git clone https://github.com/Cacti/cacti.git


else 
wget https://github.com/Cacti/cacti/archive/release/$version.zip
unzip $version 
mv cacti-release-$version cacti
fi


mv $currentpath/cacti  /tmp
mv cacti $currentpath

echo "adding old config.php file into new cacti folder"
cp /tmp/cacti/include/config.php $currentpath/cacti/include/config.php

echo "Moving plugin files back into new cacti folder"
cp -R /tmp/cacti/plugins/* $currentpath/cacti/plugins/



echo "what system user do you run cacti as ? usually www-data hit enter for default"
read cactiuser
if [ "$cactiuser" == "" ]
then 
cactiuser="www-data"

fi
chown -R $cactiuser:$cactiuser $currentpath/cacti



echo "cacti has been upgraded to  " + $version
echo " a backup of your previous release has been made to /tmp"
echo "once you have confirmed everything is working remove the backup from /tmp"




systemctl start cron

}





#####Menu 




choice='Select a operation: '
options=("New-installation" "spine-only-installation" "cacti-upgrade" "Quit")
select opt in "${options[@]}"
do
    case $opt in
        "New-installation")
            new_install
            ;;
        "spine-only-installation")
            spine_install
            ;;
        "cacti-upgrade")
            cacti_upgrade
            ;;
        "Quit")
            break
            ;;
        *) echo invalid option;;
    esac
done

