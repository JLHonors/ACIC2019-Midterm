#!/bin/bash

IRODS_USER=YOUR_USERNAME
IRODS_PASS=YOUR_PASSWORD

IRODS_GROUP=iplant-everyone

#######################################################
#
# DO NOT Modify anything below this
#
#######################################################
SEQSERVER_USER=seqserver
SEQSERVER_GROUP=seqserver_group

SEQSERVER_BASE_PATH=/var/www/sequenceserver
SEQSERVER_APP_PATH=/var/www/sequenceserver/app
SEQSERVER_JOB_PATH=/var/www/sequenceserver/.sequenceserver
SEQSERVER_CONFIG_PATH=/var/www/sequenceserver
SEQSERVER_CONFIG_FILE=/var/www/sequenceserver/.sequenceserver.conf
SEQSERVER_DB_PATH=/var/www/sequenceserver/db
SEQSERVER_NUM_PROCESS=1

if [ -z $SUDO_USER ]; then
    echo "Need to run the script as sudo"
    exit -1
fi
if [ $IRODS_USER == "YOUR_USERNAME" ]; then
    echo "Change IRODS_USER in script"
    exit -1
fi
if [ $IRODS_PASS == "YOUR_PASSWORD" ]; then
    echo "Change IRODS_PASS in script"
    exit -1
fi

#
# Update and Upgrade
sudo apt-get update -y


#
# Install our PGP key and add HTTPS support for APT
sudo apt-get install -y dirmngr gnupg
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 561F9B9CAC40B2F7
sudo apt-get install -y apt-transport-https ca-certificates

#
# Add our APT repository
sudo sh -c 'echo deb https://oss-binaries.phusionpassenger.com/apt/passenger bionic main > /etc/apt/sources.list.d/passenger.list'
sudo apt-get update

#
# Install Passenger + Nginx module
# https://www.phusionpassenger.com/library/install/standalone/install/oss/stretch/
sudo apt-get install -y ruby ruby-dev nginx libnginx-mod-http-passenger redis-server build-essential zlib1g-dev curl wget git

#
# Check passenger installation
sudo /usr/bin/passenger-config validate-install --auto


#
# Install bundler
sudo gem install bundler

#
# Create user
sudo addgroup $SEQSERVER_GROUP
sudo adduser --quiet --disabled-login --gecos 'SequenceServer' $SEQSERVER_USER
sudo adduser $SEQSERVER_USER $SEQSERVER_GROUP
sudo adduser $SUDO_USER $SEQSERVER_GROUP
sudo adduser www-data $SEQSERVER_GROUP
#sudo echo "DenyUsers $SEQSERVER_USER" >> /etc/ssh/sshd_config
#sudo systemctl restart sshd

#
# Create necessary directory, and change owner
sudo mkdir -p $SEQSERVER_BASE_PATH
sudo mkdir -p $SEQSERVER_JOB_PATH
sudo mkdir -p $SEQSERVER_APP_PATH
sudo mkdir -p $SEQSERVER_CONFIG_PATH
sudo mkdir -p $SEQSERVER_DB_PATH
sudo chown -R $SEQSERVER_USER:$SEQSERVER_GROUP $SEQSERVER_BASE_PATH
sudo chown -R $SEQSERVER_USER:$SEQSERVER_GROUP $SEQSERVER_JOB_PATH
sudo chown -R $SEQSERVER_USER:$SEQSERVER_GROUP $SEQSERVER_APP_PATH
sudo chown -R $SEQSERVER_USER:$SEQSERVER_GROUP $SEQSERVER_CONFIG_PATH
sudo chown -R $SEQSERVER_USER:$IRODS_GROUP $SEQSERVER_DB_PATH
sudo chmod o-rwx $SEQSERVER_BASE_PATH
sudo chmod -R o-w $SEQSERVER_APP_PATH
sudo chmod -R o-w $SEQSERVER_DB_PATH

#
# Download SequenceServer
git clone https://github.com/zhxu73/sequenceserver-scale.git $SEQSERVER_APP_PATH

#
# Install the dependencies of SequenceServer
cd $SEQSERVER_APP_PATH
bundle install --path vendor/bundle --without development test

#
# Create config file
cd ~/
git clone https://github.com/JLHonors/ACIC2019-Midterm.git
cp ACIC2019-Midterm/deploy/.sequenceserver.conf $SEQSERVER_CONFIG_FILE

#
# Download sample database
cd ~/
curl ftp://ftp.ncbi.nlm.nih.gov/blast/db/vector.tar.gz -O
sudo tar -xvf vector.tar.gz -C $SEQSERVER_DB_PATH/
rm ~/vector.tar.gz

#
# Setup iRODs
touch ~/password.txt
chmod 600 ~/password.txt
chown $SUDO_USER:root ~/password.txt
echo $IRODS_PASS > ~/password.txt
mkdir -p ~/.irods/
echo "{ \"irods_zone_name\": \"iplant\", \"irods_host\": \"data.cyverse.org\", \"irods_port\": 1247, \"irods_user_name\": \"$IRODS_USER\" }" > ~/.irods/irods_environment.json
iinit < ~/password.txt
irsync -r i:/iplant/home/$IRODS_USER/db /var/www/sequenceserver/db

#
# Install BLAST
cd ~/
curl ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/LATEST/ncbi-blast-2.9.0+-x64-linux.tar.gz -O
tar -xvf ncbi-blast-2.9.0+-x64-linux.tar.gz
sudo cp ncbi-blast-2.9.0+/bin/* /usr/bin
rm ~/ncbi-blast-2.9.0+-x64-linux.tar.gz
rm -rf ~/ncbi-blast-2.9.0+

#
# Install cctools (WorkQueue)
cd ~/
wget http://ccl.cse.nd.edu/software/files/cctools-7.0.19-x86_64-centos7.tar.gz
tar -xvf cctools-7.0.19-x86_64-centos7.tar.gz
mv cctools-7.0.19-x86_64-centos7 cctools
sudo cp cctools/bin/* /usr/bin
rm cctools-7.0.19-x86_64-centos7.tar.gz

#
# Install blast-workqueue
cd ~/
git clone https://github.com/zhxu73/blast-workqueue.git
cd blast-workqueue/src
make
sudo cp blast_workqueue /usr/bin
sudo cp blast_workqueue-backend /usr/bin
cd ~/
rm -rf ~/blast-workqueue
rm -rf ~/cctools

#
# Install Systemd Service
cd ~/ACIC2019-Midterm/deploy
sudo cp blast_db_sync.service /etc/systemd/system
sudo cp blast_db_sync.timer /etc/systemd/system
sudo cp blast_workqueue.service /etc/systemd/system
cp sync_blast_db.sh /var/www/sequenceserver
sudo systemctl daemon-reload

#
# Start DB sync service and WQ backend service
sudo systemctl enable blast_db_sync.timer
sudo systemctl start blast_db_sync.timer
sudo systemctl enable blast_workqueue.service
sudo systemctl start blast_workqueue.service


#
# Nginx Config
cd ~/
wget https://raw.githubusercontent.com/JLHonors/ACIC2019-Midterm/master/deploy/nginx_seqserver.conf
sudo mv nginx_seqserver.conf /etc/nginx/sites-available/sequenceserver.conf
sudo ln -s /etc/nginx/sites-available/sequenceserver.conf /etc/nginx/sites-enabled/sequenceserver.conf
sudo rm /etc/nginx/sites-enabled/default
sudo nginx -s reload

#
# Start Nginx
sudo systemctl restart nginx


