#!/bin/bash

##Author Sean Mancini
#www.seanmancini.com
#Version 2.0

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



if
[[ $(id -u) -ne 0 ]] ;
then echo "this script must be run as root" ;
sudo su  ; fi






echo "this script requires git"
yum install -y git



function new_install () {


echo "This script will download all Cacti dependecies and download the chosen cacti version from the cacti github"
echo "Dont forget to support cacti @ cacti.net!"


echo "set selinux to disabled"
setenforce 0 
sed -i 's/enforcing/disabled/g' /etc/selinux/config /etc/selinux/config


#Download chosen release
echo "here are some of the current cacti release versions"

git ls-remote --tags https://github.com/Cacti/cacti|grep 'release/[[:digit:]\.]*$'|tail -10|awk '{print $2}'|tr 'refs/tags/release' ' '|sed 's/^ *//;s/ *$//'


echo  "which release would you like to download ? Hit enter for latest"
read version

if  [ "$version" == "" ]
then
git clone -b 1.2.x https://github.com/Cacti/cacti.git


else 
yum install -y wget unzip
wget https://github.com/Cacti/cacti/archive/release/$version.tar.gz
tar -xvf  $version.tar.gz 
mv cacti-release-$version cacti
fi




echo "will you be using the spine poller enter 1 for yes 2 for no"
read answer
if [ $answer == "1" ]
then
##Download packages needed for spine
yum install -y gcc mysql-devel net-snmp-devel autoconf automake libtool dos2unix help2man
echo "downloading and compling spine"
git clone https://github.com/Cacti/spine.git
cd spine
chmod +x bootstrap
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




echo "Enable Mariadb 10.4 Repo"
wget https://downloads.mariadb.com/MariaDB/mariadb_repo_setup
chmod +x mariadb_repo_setup
./mariadb_repo_setup





echo "On Centos systems we need to enable EPEL repos"
yum install http://rpms.remirepo.net/enterprise/remi-release-7.rpm -y
yum install yum-utils -y
yum-config-manager --enable remi-php73



echo "Downloading PHP modules needed for Cacti install"

yum install  -y rrdtool mariadb-server net-snmp-utils   snmpd php php-mysql  php-snmp php-xml php-mbstring php-json php-gd php-gmp php-zip php-ldap php-mc php-posix 



###Start services 

systemctl enable httpd
systemctl enable mariadb
systemctl start mariadb
systemctl start httpd



####Open Port 80 and 443 on firewalld

echo "Open http and https ports on firewalld"
firewall-cmd --zone=public --add-port=80/tcp --permanent
firewall-cmd --zone=public --add-port=443/tcp --permanent
firewall-cmd --reload



##Timezone settings needed for cacti
echo "Enter your PHP time zone i.e America/Toronto  Default is US/Central "
read timezone
if [$timezone = ""] 
then


echo "date.timezone =" US/Central >> /etc/php.ini
else


echo "date.timezone =" "$timezone" >> /etc/php.ini

fi  



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
echo "Which user would you like to run Cacti under (Default is apache) hit enter for default"
read user
if [$user = ""]
then 
user="apache"
echo  "cacti will be run under apache"
chown -R  apache:apache $location/cacti
else 
useradd $user
chown -R $user:$user $location/cacti
fi


#assign permissions for cacti installation

chown -R apache:apache $location/cacti/resource/snmp_queries/          
chown -R apache:apache $location/cacti/resource/script_server/
chown -R apache:apache $location/cacti/resource/script_queries/
chown -R apache:apache $location/cacti/scripts/
chown -R apache:apache $location/cacti/cache/boost/
chown -R apache:apache $location/cacti/cache/mibcache/
chown -R apache:apache $location/cacti/cache/realtime/
chown -R apache:apache $location/cacti/cache/spikekill/
touch $location/cacti/log/cacti.log
chmod 664 $location/cacti/log/cacti.log
chown -R apache:apache   $location/cacti/log/
cp $location/cacti/include/config.php.dist $location/cacti/include/config.php
chown -R apache:apache $location/cacti/include/config.php



###Make a backup of maria db config before making changes
cp /etc/my.cnf.d/server.cnf /etc/my.cnf.d/server.cnf.backup



echo "Applying recommended DB settings"
echo "
innodb_file_format = Barracuda
character_set_client = utf8mb4
max_allowed_packet = 16777777
join_buffer_size = 32M
innodb_file_per_table = ON
innodb_large_prefix = 1
innodb_buffer_pool_size = 250M
innodb_flush_log_at_trx_commit = 2
innodb_doublewrite = ON
innodb_flush_log_at_timeout = 3
innodb_read_io_threads = 32
innodb_write_io_threads = 16
innodb_io_capacity = 5000
innodb_io_capacity_max = 10000
" >> /etc/my.cnf.d/server.cnf

systemctl restart mariadb


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
sed -i -e 's@^$database_username.*@$database_username = 'cacti';@g' /var/www/html/cacti/include/config.php
sed -i -e 's@^$database_password.*@$database_password = "'$password'";@g' /var/www/html/cacti/include/config.php
sed -i -e 's@^$database_port.*@$database_port = "3306";@g' /var/www/html/cacti/include/config.php
sed -i -e 's@^$database_ssl.*@$database_ssl = "false";@g' /var/www/html/cacti/include/config.php
sed -i -e 's@^//$url_path@$url_path@g' /var/www/html/cacti/include/config.php
###Cacti spine settomgs
cp /usr/local/spine/etc/spine.conf.dist /usr/local/spine/etc/spine.conf
sed -i -e 's@^DB_Host.*@DB_Host  127.0.0.1@g' /usr/local/spine/etc/spine.conf
sed -i -e 's@^DB_User.*@DB_User  cacti@g' /usr/local/spine/etc/spine.conf
sed -i -e 's@^DB_Pass.*@DB_Pass  cacti@g' /usr/local/spine/etc/spine.conf




echo "default database setup with following details"
echo "database name cacti\n
database username cacti\n
database password $password"






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
cp /usr/local/spine/etc/spine.conf.dist /usr/local/spine/etc/spine.conf
sed -i -e 's@^DB_Host.*@DB_Host  127.0.0.1@g' /usr/local/spine/etc/spine.conf
sed -i -e 's@^DB_User.*@DB_User  '$customdbuser'@g' /usr/local/spine/etc/spine.conf
sed -i -e 's@^DB_Pass.*@DB_Pass  '$customdbpassword'@g' /usr/local/spine/etc/spine.conf

fi





###Adding recomended PHP settings 
sed -e 's/max_execution_time = 30/max_execution_time = 60/' -i /etc/php.ini
sed -e 's/memory_limit = 128M/memory_limit = 400M/' -i /etc/php.ini


echo "Restarting Mariadb service"
systemctl restart mariadb




echo "this script can download the following plugins monitor,thold would you like to install them  ? type yes to download hit enter to skip"
read plugins
 if [[ $plugins = "yes" ]]
  then
   git clone https://github.com/Cacti/plugin_thold.git thold thold
    git clone https://github.com/Cacti/plugin_monitor.git monitor
     mv thold $location/cacti/plugins
      mv monitor $location/cacti/plugins
else
 echo "plugins will not be installed"
fi


echo "Would you like to download my RRD Monitoring script ? type yes to download hit enter to skip "
read mon_script
if [[  $mon_script == "yes" ]]
  then
  git clone  https://github.com/bmfmancini/rrd-monitor.git
      else
       echo "Script will not be downloaded"
fi



touch /etc/cron.d/$user
echo "*/5 * * * * $user php $location/cacti/poller.php > /dev/null 2>&1" > /etc/cron.d/$user 





echo "refreshing services"
systemctl restart httpd
systemctl restart mariadb


echo "The setup has completed you can now either install cacti via the CLI or access the websetup to continue install via CLI type yes"
read installanswer
if [[  $installanswer == "yes" ]]
then 
php $location/cacti/cli/install_cacti.php --accept-eula --install -d
else 
echo "please complete install on web console"
fi


}


function spine_install () {


##Download packages needed for spine

yum install -y gcc mysql-devel net-snmp-devel autoconf automake libtool dos2unix help2man

echo " Which version of spine would you like to use ? Hit enter for the latest or enter the release vesrion i.e 1.2.3 Usually should Match your installed version of Cacti"
read version

if [$version = ""]
then

echo "downloadinglatest version of spine  and compling "
git clone https://github.com/Cacti/spine.git
cd spine
chmod +x bootstrap
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
chmod +x bootstrap
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
systemctl stop crond


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
echo "specify a backup path to backup cacti files default is /tmp"
read backpath
if [  "$backpath" == "" ]
then
backpath="/tmp"
fi

echo "backing up DB"
mysqldump -u $currentdbuser -p $currentdbpassword   $currentdb > cacti_db_backup.sql



echo  "which release would you like to upgrade to? Hit enter for latest"
read version

if  [ "$version" == "" ]
then
git clone -b 1.2.x https://github.com/Cacti/cacti.git


else 
wget https://github.com/Cacti/cacti/archive/release/$version.zip
unzip $version 
mv cacti-release-$version cacti
fi


mv $currentpath/cacti  $backpath
mv cacti $currentpath

echo "adding old config.php file into new cacti folder"
cp $backpath/cacti/include/config.php $currentpath/cacti/include/config.php

echo "Moving plugin files back into new cacti folder"
cp -R $backpath/cacti/plugins/* $currentpath/cacti/plugins/



echo "what system user do you run cacti as ? usually www-data"
read cactiuser

chown -R $cactiuser:$cactiuser $currentpath/cacti



echo "cacti has been upgraded to  "  $version
echo " a backup of your previous release has been made to"  $backpath
echo "once you have confirmed everything is working remove the backup from"  $backpath




systemctl start crond


echo "Would you like to update spine ? hit enter to skip"
read spineupdate

if  [ "$spineupdate" == "yes" ]
then
spine_install
else
echo "upgrade complete"
fi
}



function remote_poller_setup () {
echo "CAUTION THIS FUNCTION IS STILL IN BETA!!!!"
echo "This function  will help you setup remote pollers for Cacti this will need to be run on each remote poller"
echo "This MUST! be run on the server you intend to be a remote poller"
echo "You must create the below user on the main poller as well the script will output the commands needed"

echo "Enter Cacti DB name"
read cacti_db

echo "Enter a username for the remote poller"
read remoteusername

echo "Enter a password for the remote poller user"
read remotepwd

echo "Enter the IP address of the Main poller"
read main_poller_ip



echo "Creating mysql user"
mysql -u root <<MYSQL_SCRIPT
GRANT ALL PRIVILEGES ON $cacti_db.* TO '$remoteusername'@'$main_poller_ip' IDENTIFIED BY '$remotepwd';
MYSQL_SCRIPT

echo "Updating cacti config.php"


echo "Enter location of cacti config.php usually in /var/www/html/cacti/include/config.php"
read location

cp $location /tmp

sed -i -e 's@^#$rdatabase_type.*@$rdatabase_type = "mysql";@g' $location
sed -i -e 's@^#$rdatabase_default.*@$rdatabase_default = '$cacti_db'\;@g' $location
sed -i -e 's@^#$rdatabase_hostname.*@$rdatabase_hostname = '$main_poller_ip'@g' $location
sed -i -e 's@^#$rdatabase_username.*@$rdatabase_username = '$remoteusername';@g' $location
sed -i -e 's@^#$rdatabase_password.*@$rdatabase_password = '$remotepwd';@g' $location
sed -i -e 's@^#$rdatabase_port.*@$rdatabase_port = "3306";@g' "$location"



#if [ $spine_answer == "y" ]
cp /usr/local/spine/etc/spine.conf /tmp
sed -i -e 's@^RDB_Host.*@RDB_Host  '$main_poller_ip'@g' /usr/local/spine/etc/spine.conf
sed -i -e 's@^RDB_User.*@RDB_User  '$remoteusername'@g' /usr/local/spine/etc/spine.conf
sed -i -e 's@^RDB_Pass.*@RDB_Pass  '$remotepwd'@g' /usr/local/spine/etc/spine.conf



echo "You must enter the following commands on the Main poller before the remote poller will work"
echo "GRANT ALL PRIVILEGES ON $cacti_db.* TO '$remoteusername'@'IP address/DNS of this server' IDENTIFIED BY '$remotepwd';"




}



#####Menu 




choice='Select a operation: '
options=("New-installation" "spine-only-installation" "cacti-upgrade" "Remote Poller Setup" "Quit")
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
	"Remote Poller Setup")
	   remote_poller_setup
           ;;
        "Quit")
            break
            ;;
        *) echo invalid option;;
    esac
done
