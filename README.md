Cacti server setup wizard <br>

this script requires git and unzip<br>

#Debian
To use the script <br>
git clone https://github.com/bmfmancini/cacti-auto-install.git <br>
cd cacti-auto-install <br>
chmod +x cacti-setup-wizard-debian-Ubuntu.sh  <br>
./cacti-setup-wizard-debian-Ubuntu.sh  <br>
RUN THE SCRIPT AS ROOT!!


The script also works on RHEL however you MUST enable EPEL prior to running the script and ensure its working
to enable RHEL EPEL reports you can use the following command 
```
yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
```


- features are

-download either chosen or latest version of cacti<br>
-autoconfigure database either with defaults or chose credentials<br>
-auto tunes MariaDB using cacti recommended settings<br>
-auto-populates cacti database<br>
-downloads all needed packages for cacti install<br>
-asks if you want to install spine if so it will automatically compile it<br>
-adds system user and assigns permissions to folders<br>
-downloads and installs plugins<br>

TODO 

Debug
Add more plugins to download option<br>
add option to select specific plugins from list<br>
Document script


BUGS

##  July 6th 2021 - Script is not working on Centos 8 will have a fix soon !

any other bugs
Please let me know!


Check out my video tutorial on using the script !


[![Video Tutorial ](http://img.youtube.com/vi/koUcuQT0KIU/0.jpg)](https://youtu.be/koUcuQT0KIU "Video Tutorial")




