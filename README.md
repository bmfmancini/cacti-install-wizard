Cacti server setup wizard <br>

this script requires git and unzip<br>

To use the script <br>
git clone https://github.com/bmfmancini/cacti-auto-install.git <br>
cd cacti-auto-install <br>
chmod +x cacti-setup-wizard.sh <br>
./cacti-setup-wizard.sh <br>
RUN THE SCRIPT AS ROOT!!




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






