#!/bin/bash

# This script installs the WAD software for Linux
# Tested for RedHat Enterprise 7
# May work for CentOS or should at least provides substantial amount of hints.

echo
echo "WAD Installer for RedHat v1.0"


# config file of apache web server (httpd.service)
HTTPD_CONF=/etc/httpd/conf/httpd.conf


############################################################################################
# Configuration of installation paths, etc
############################################################################################

TARGET_DCM4CHEE=/opt
TARGET_WAD_SERVICES=/opt
TARGET_XML=/opt
TARGET_WAD_INTERFACE=/var/www
# quoted and escaped version for httpd.conf file
TARGET_WAD_INTERFACE_HTTPD_CONFIG='\"\/var\/www\"'
TARGET_STARTSCRIPT=/usr/local/bin

ZIP_DCM4CHEE=source/dcm4chee-2.17.1-mysql.zip
ZIP_DCM4CHEE_ARR=source/dcm4chee-arr-3.0.11-mysql.zip
#ZIP_DCM4CHEE_CDW=source/dcm4chee-cdw-2.17.0.zip
#ZIP_DCM4CHEE_WEB=source/dcm4chee-web-3.0.3-mysql.zip
ZIP_JBOSS=source/jboss-4.2.3.GA-jdk6.zip



############################################################################################
## Check dependencies:
############################################################################################


# check if current user is root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root or using sudo" 1>&2
   exit 1
fi


# check for RedHat Enterprise
# if lsb_release is not installed use yum to install package redhat-lsb-core
[ ! -f /usr/bin/lsb_release ] && sudo yum -y install redhat-lsb-core

distro=$(lsb_release -i | awk '{print $3}')

if [[ "$distro" != "RedHatEnterpriseServer" ]]; then
	echo "Sorry, this script is only known to run on RedHat Enterprise 7.0"
	exit 1
fi

# update packagelist
#apt-get update
# yum updates itself automatically

# check if zip files are present (and/or if placeholders were replaced)
for i in "$ZIP_DCM4CHEE" "$ZIP_DCM4CHEE_ARR" "$ZIP_JBOSS"; do
   if [ -s $i ]
           then
		# zip-file exists and is not empty, so continue script
		:
           else
		echo
           	echo File $i does not exist or is empty. Please correct the problem and try again.
		echo
		exit 1
   fi
done

# check if WAD_Services and WAD_Interface folders are present
for i in "services" \
	 "source" \
	 "source/WAD_Interface/create_databases" \
	 "source/WAD_Interface/website" \
	 "source/WAD_Services/WAD_Collector" \
	 "source/WAD_Services/WAD_Selector" \
	 "source/WAD_Services/WAD_Processor" ; do
   if [ -d $i ]
           then
		# folder exists, so continue script
		:
           else
		echo
           	echo Folder $i not found. Please correct the problem and try again.
		echo
		exit 1
   fi
done

# check if WAD-folders are not empty (only several important files are checked)
for i in "source/WAD_Interface/website/index.php" \
	 "source/WAD_Interface/create_databases/create_dcm4chee_tables.sh" \
	 "source/WAD_Interface/create_databases/create_iqc_tables.sh" \
	 "source/WAD_Services/WAD_Collector/dist/WAD_Collector.jar" \
	 "source/WAD_Services/WAD_Selector/dist/WAD_Selector.jar" \
	 "source/WAD_Services/WAD_Processor/dist/WAD_Processor.jar" ; do
   if [ -s $i ]
           then
		# file exists, so continue script
		:
           else
		echo
           	echo File $i does not exist or is empty. Please correct the problem and try again.
		echo
		exit 1
   fi
done



############################################################################################
# Install jdk/jre
############################################################################################

echo "Detected java version: "
echo
[ -f /usr/bin/java ] && java -version
echo

yesno=n

if [ -f /usr/bin/java ]; then
        echo
        read -n 1 -p "Skip installing java jre/jdk? [Y/n] " yesno
		echo
fi

if [[ "$yesno" != "" && "$yesno" != "y" && "$yesno" != "Y" ]] ; then
        echo
		echo "Which JAVA version do you want to install?"
        echo "1. none"
        echo "2. java-1.6.0-openjdk-devel"
        echo "3. java-1.6.0-openjdk"
        echo "4. java-1.7.0-openjdk-devel"
        echo "5. java-1.7.0-openjdk"
# required version of JBOSS doesnt work with java 1.8
#        echo "6. java-1.8.0-openjdk-devel"
#        echo "7. java-1.8.0-openjdk"
		echo

        read -n 1 -p "Which version of java do you want to install? " option
		echo
        if [ $option == "2" ]; then
                JAVA=java-1.6.0-openjdk-devel
        fi
        if [ $option == "3" ]; then
                JAVA=java-1.6.0-openjdk
        fi
        if [ $option == "4" ]; then
                JAVA=java-1.7.0-openjdk-devel
        fi
        if [ $option == "5" ]; then
                JAVA=java-1.7.0-openjdk
        fi
#        if [ $option == "6" ]; then
#                JAVA=java-1.8.0-openjdk-devel
#        fi
#        if [ $option == "7" ]; then
#                JAVA=java-1.8.0-openjdk
#        fi
fi

#apt-get -y install $JAVA
yum -y install $JAVA


############################################################################################
# Installing "LAMP"
# The following command installs the following components:
# openssh-server; apache2; mysql-server; mysql-client; php; phpmyadmin
############################################################################################

#~ mysql is not in the RedHat repo's
#~ echo "Installing mysql: add mysql community repository"
#~ wget http://dev.mysql.com/get/mysql57-community-release-el7-9.noarch.rpm
#~ yum localinstall -y mysql57-community-release-el7-9.noarch.rpm

#~ # check if new repo was correctly added.
#~ echo "Installing mysql: check that mysql community repository is listed below"
#~ yum repolist enabled | grep "mysql.*-community.*"

#~ echo "Installing mysql: install package mysql-community-server"
#~ yum install -y mysql-community-server

#~ echo "Installing mysql: starting service"
#~ systemctl start mysqld

#~ echo "Installing mysql: display status of service"
#~ systemctl status mysqld

#~ # start server at sustem startup
#~ systemctl enable mysqld

# install mariadb (drop-in replacement for mysql)
# by default mariadb uses /var/lib/mysql for database storage
yum -y install mariadb mariadb-server
systemctl start mariadb
systemctl enable mariadb

# install apache
yum -y install httpd openssh-server

# phpMyAdmin needs repository "rhel-7-server-optional-rpms"
subscription-manager repos --enable=rhel-7-server-optional-rpms
yum -y install phpMyAdmin

# DCMTK not in RedHat repo
# apt-get -y install dcmtk

yum -y install php-pear
pear install --alldeps mail

############################################################################################


SOURCEDIR=`pwd`

echo
echo "Stopping apache httpd"
systemctl stop httpd

# wijzig in c:\xampp\php\php.ini de regels:
#   upload_max_filesize = 2M -> upload_max_filesize = 200M
#   post_max_size = 8M       -> post_max_size = 200M

perl -pi -e 's/^upload_max_filesize = 2M/upload_max_filesize = 200M/g' /etc/php.ini
perl -pi -e 's/^post_max_size = 8M/post_max_size = 200M/g' /etc/php.ini

# 1. Maak de folder c:\WAD-software aan en kopieer de mappen WAD Interface en WAD Service hier naartoe. WAD Interface bevat de website en de database create-scripts WAD Service bevat de benodigde java applicaties

echo
echo "Starting apache httpd"
systemctl start httpd
systemctl enable httpd
echo "Finished starting apache httpd"


############################################################################################
############################################################################################

DCM4CHEE_FOLDER=$TARGET_DCM4CHEE/$(basename $ZIP_DCM4CHEE .zip)
JBOSS_FOLDER=$TARGET_DCM4CHEE/$(unzip -qql $ZIP_JBOSS | head -n1 | awk {'print $4'})


echo
echo "Installing DCM4CHEE - MySql"
unzip $ZIP_DCM4CHEE -d $TARGET_DCM4CHEE
#tar -C /opt -xzvf source/dcm4chee-2.17.1-mysql.tgz
chmod +x $DCM4CHEE_FOLDER/bin/run.sh

# onder x64 krijg je een fout bij het starten van de WADO service
#        (stap 8 van http://www.dcm4che.org/confluence/display/ee2/Installation)
#   werkt: com.sun.imageio.plugins.jpeg.JPEGImageWriter

MACHINE_TYPE=`uname -m`
if [ ${MACHINE_TYPE} == 'x86_64' ]; then
   perl -pi -e 's/value="com.sun.media.imageioimpl.plugins.jpeg.CLibJPEGImageWriter"/value="com.sun.imageio.plugins.jpeg.JPEGImageWriter"/g' $DCM4CHEE_FOLDER/server/default/conf/xmdesc/dcm4chee-wado-xmbean.xml
fi

echo "Finished installing DCM4CHEE - MySQL"

############################################################################################
# First-time run for mysql only...
############################################################################################

echo
read -n 1 -p "Run mysql_secure_installation (needed only once after new install)? [Y/n] " yesno
if [[ "$yesno" == "" || "$yesno" == "y" || "$yesno" == "Y" ]] ; then
	echo Note that for fresh install of mysql the root password is empty
	mysql_secure_installation
fi

############################################################################################
# Ask for Mysql root password
############################################################################################

echo
read -s -p "Please provide your mysql root-password: " mysqlpwd
echo
echo


echo 
echo "Creating dcm4chee user"
id -u pacs &>/dev/null || useradd pacs
chown -R pacs:pacs $DCM4CHEE_FOLDER/server/

echo
echo "Creating DCM4CHEE tables (this can take a while)"
perl -pi -e "s%^mysql -upacs -ppacs pacsdb.*$/%mysql -upacs -ppacs pacsdb < $TARGET_DCM4CHEE/$(basename $ZIP_DCM4CHEE .zip)/sql/create.mysql\n%g" source/WAD_Interface/create_databases/create_dcm4chee_tables.sh
bash source/WAD_Interface/create_databases/create_dcm4chee_tables.sh $mysqlpwd
echo "Finished creating DCM4CHEE tables"

echo
echo "Installing JBOSS"
unzip $ZIP_JBOSS -d $TARGET_DCM4CHEE
bash  $DCM4CHEE_FOLDER/bin/install_jboss.sh $JBOSS_FOLDER
echo "Finished installing JBOSS"


#echo "Installing DCM4CHEE - CDW"
#unzip source/dcm4chee-cdw-2.17.0.zip -d /opt
#bash  /opt/dcm4chee-2.17.3-mysql/bin/install_cdw.sh /opt/dcm4chee-cdw-2.17.0/
#echo "Finished installing DCM4CHEE - CDW"

echo
echo "Installing DCM4CHEE - ARR"
unzip $ZIP_DCM4CHEE_ARR -d $TARGET_DCM4CHEE
bash  $DCM4CHEE_FOLDER/bin/install_arr.sh $TARGET_DCM4CHEE/$(basename $ZIP_DCM4CHEE_ARR .zip)
echo "Finished installing DCM4CHEE - ARR"


#echo "Installing DCM4CHEE - WEB" 
#cp source/dcm4chee-web-3.0.3-mysql.zip   /usr/local/
#unzip /usr/local/dcm4chee-web-3.0.3-mysql.zip -d /usr/local
#bash  /usr/local/dcm4chee-web-3.0.3-mysql/bin/install.sh /usr/local/dcm4chee-2.17.3-mysql/
#echo "Finished installing DCM4CHEE - WEB" 



############################################################################################
# Install WAD Software (Services + Interface)
############################################################################################

echo
echo "Creating IQC tables"
bash source/WAD_Interface/create_databases/create_iqc_tables.sh $mysqlpwd
echo "Finished creating IQC tables"

echo
echo "Installing WAD Interface"

# modify location of default website of apache 2.4
#perl -pi -e 's/DocumentRoot \/var\/www\/html/DocumentRoot \/var\/www/g' /etc/apache2/sites-available/000-default.conf
# /var/www must be replaced by $TARGET_WAD_INTERFACE
#perl -pi -e 's/DocumentRoot \"\/var\/www\/html\"/DocumentRoot \"\/var\/www\"/g' /etc/httpd/conf/httpd.conf
perl -pi -e 's/\"\/var\/www\/html\"/'$TARGET_WAD_INTERFACE_HTTPD_CONFIG'/g' $HTTPD_CONF
perl -pi -e 's/\"\/var\/www\"/\"\'$TARGET_WAD_INTERFACE_HTTPD_CONFIG'/g' $HTTPD_CONF

mkdir $TARGET_WAD_INTERFACE
[ -f $TARGET_WAD_INTERFACE/index.html ] && mv $TARGET_WAD_INTERFACE/index.html $TARGET_WAD_INTERFACE/index.old
cp -RL source/WAD_Interface/website/* $TARGET_WAD_INTERFACE
#cp source/wadiqc /etc/apache2/sites-available
#a2ensite wadiqc
#bash /etc/init.d/apache2 restart
systemctl restart httpd


echo "Get httpd user and group from $HTTPD_CONF"
HTTPD_USER=`cat $HTTPD_CONF| grep "User " | awk {'print $2'}`
HTTPD_GROUP=`cat $HTTPD_CONF | grep "Group " | awk {'print $2'}`
echo "httpd user:group is $HTTPD_USER:$HTTPD_GROUP"

# stop here if empty user/group
if [ "X$HTTPD_USER" == "X" ] || [ "X$HTTPD_GROUP" == "X" ] ; then
	echo "Could not find user or group of httpd. Location of http config file may not be correct. Stopping script."
	exit
fi

chown -R $HTTPD_USER:$HTTPD_GROUP $TARGET_WAD_INTERFACE/*
chmod u+x -R $TARGET_WAD_INTERFACE/*

echo
echo "Installing WAD Services"

cp -RL source/WAD_Services/ $TARGET_WAD_SERVICES
mkdir -p $TARGET_XML/XML/analysemodule_output
mkdir -p $TARGET_XML/XML/analysemodule_input
chown -R $HTTPD_USER:$HTTPD_GROUP $TARGET_WAD_SERVICES/WAD_Services
chown -R $HTTPD_USER:$HTTPD_GROUP $TARGET_XML/XML

# modify config.xml
perl -pi -e "s%^(\s*<uploads>).*(</uploads>\s*$)%\1$TARGET_WAD_INTERFACE/\2%g" $TARGET_WAD_SERVICES/WAD_Services/config.xml
perl -pi -e "s%^(\s*<XML>).*(</XML>\s*$)%\1$TARGET_XML/\2%g" $TARGET_WAD_SERVICES/WAD_Services/config.xml
perl -pi -e "s%^(\s*<archive>).*(</archive>\s*$)%\1$TARGET_DCM4CHEE/$(basename $ZIP_DCM4CHEE .zip)/server/default/\2%g" $TARGET_WAD_SERVICES/WAD_Services/config.xml


############################################################################################
# Install services
############################################################################################

cp services/WAD-Services $TARGET_STARTSCRIPT/
chmod +x $TARGET_STARTSCRIPT/WAD-Services

echo
read -n 1 -p "Install dcm4chee as a service? [Y/n] " yesno
if [[ "$yesno" == "" || "$yesno" == "y" || "$yesno" == "Y" ]] ; then
echo
	cp services/systemd/dcm4chee.service /usr/lib/systemd/system
	perl -pi -e "s%^ExecStart=.*$%ExecStart=$DCM4CHEE_FOLDER/bin/run.sh%g" /usr/lib/systemd/system/dcm4chee.service
	perl -pi -e "s%^ExecStop=.*$%ExecStop=$DCM4CHEE_FOLDER/bin/shutdown.sh -S%g" /usr/lib/systemd/system/dcm4chee.service
	
	systemctl daemon-reload
	# start service now
	systemctl start dcm4chee
	# start service at system boot time
	systemctl enable dcm4chee
fi

echo
read -n 1 -p "Install WAD-Services as a service? [Y/n] " yesno
echo
if [[ "$yesno" == "" || "$yesno" == "y" || "$yesno" == "Y" ]] ; then
	cp services/systemd/WAD*.service /usr/lib/systemd/system
	perl -pi -e "s%^WorkingDirectory=.*$%WorkingDirectory=$TARGET_WAD_SERVICES/WAD_Services/WAD_Collector/dist%g" /usr/lib/systemd/system/WAD-Collector.service
	perl -pi -e "s%^WorkingDirectory=.*$%WorkingDirectory=$TARGET_WAD_SERVICES/WAD_Services/WAD_Selector/dist%g" /usr/lib/systemd/system/WAD-Selector.service
	perl -pi -e "s%^WorkingDirectory=.*$%WorkingDirectory=$TARGET_WAD_SERVICES/WAD_Services/WAD_Processor/dist%g" /usr/lib/systemd/system/WAD-Processor.service
	
	systemctl daemon-reload
	# start service now
	#systemctl start WAD-Collector
	$TARGET_STARTSCRIPT/WAD-Services start
	
	# start service at system boot time
	systemctl enable WAD-Collector
	systemctl enable WAD-Selector
	systemctl enable WAD-Processor	
fi

############################################################################################

echo
echo "Services can be (re)started or stopped using:"
echo
echo "sudo systemctl <command> <servicename>"
echo
echo "e.g. sudo systemctl start WAD-Collector"
echo
echo "servicename: WAD-Collector, WAD-Selector, WAD-Processor, dcm4chee"
echo "commands: start, restart, stop, status"
echo
echo
echo "Alternatively, the command \"WAD-Services\" can be used to (re)start or stop all WAD-services at once."
echo
echo
echo "If you installed dcm4che as a system service, make sure to disable console logging, see"
echo "http://forums.dcm4che.org/jiveforums/thread.jspa?messageID=4787&#4787"
echo
echo "Finished installation, enjoy."
echo
