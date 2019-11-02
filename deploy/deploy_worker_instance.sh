#!/bin/bash

#######################################################
# Must Change
#######################################################
MASTER_IP=XX.XX.XX.XX
WORKQUEUE_PASSWORD=VERY_VERY_VERY_STRONG_PASSWORD
IRODS_SYNC_PATH=/iplant/home/your_username/db

#######################################################
# More Option
#######################################################
#MOST_WORKERS=4
#LEAST_WORKERS=2
#CORE_PER_WORKER=2
#MEM_PER_WORKER=8

ADMIN_USER=$ATMO_USER

IRODS_USER=anonymous
IRODS_PASS=YOUR_PASSWORD

#######################################################
#
# DO NOT Modify anything below this
#
#######################################################

SEQSERVER_USER=seqserver
SEQSERVER_GROUP=seqserver_group
SEQSERVER_BASE_PATH=/var/www/sequenceserver
SEQSERVER_DB_PATH=/var/www/sequenceserver/db
SEQSERVER_SYNC_PATH_FILE=/var/www/sequenceserver/irods_sync_path.txt

if [ $USER != "root" ]; then
    if [ -z $SUDO_USER ]; then
        echo "Need to run the script as sudo"
        exit -1
    fi
fi
if [ $MASTER_IP == "XX.XX.XX.XX" ]; then
    echo "Change MASTER_IP in script"
    exit -1
fi
if [ WORKQUEUE_PASSWORD == VERY_VERY_VERY_STRONG_PASSWORD ]; then
    echo "Change WORKQUEUE_PASSWORD in script"
    exit -1
fi

if [ $IRODS_USER != "anonymous" ]; then
    if [ $IRODS_USER == "YOUR_USERNAME" ]; then
        echo "Change IRODS_USER in script"
        exit -1
    fi
    if [ $IRODS_PASS == "YOUR_PASSWORD" ]; then
        echo "Change IRODS_PASS in script"
        exit -1
    fi
fi

#
#
# Update & Upgrade
sudo DEBIAN_FRONTEND=noninteractive apt-get -qq -y update

#
#
# Install with apt
sudo DEBIAN_FRONTEND=noninteractive apt-get -qq -y install wget curl

#
# Install iRODs - icommand (if not installed)
command -v iinit
if [ $? != 0 ]; then
    wget -qO - https://packages.irods.org/irods-signing-key.asc | sudo apt-key add -
    echo "deb [arch=amd64] https://packages.irods.org/apt/ xenial main" | sudo tee /etc/apt/sources.list.d/renci-irods.list
    sudo DEBIAN_FRONTEND=noninteractive apt-get -qq -y update
    sudo DEBIAN_FRONTEND=noninteractive apt-get -qq -y install irods-icommands
fi

#
# Create user
sudo addgroup $SEQSERVER_GROUP
sudo adduser --quiet --disabled-login --gecos 'SequenceServer' $SEQSERVER_USER
sudo adduser $SEQSERVER_USER $SEQSERVER_GROUP
if [ -n $SUDO_USER ]; then
    sudo adduser $SUDO_USER $SEQSERVER_GROUP
fi
if [ -n $SUDO_USER ]; then
    sudo adduser $ADMIN_USER $SEQSERVER_GROUP
fi

#
#
# Store IP of WQ master into file
cd ~/
mkdir -p $SEQSERVER_BASE_PATH
touch $SEQSERVER_BASE_PATH/master_ip.txt
chmod 640 $SEQSERVER_BASE_PATH/master_ip.txt
echo $MASTER_IP > $SEQSERVER_BASE_PATH/master_ip.txt
chown -R $SEQSERVER_USER:$SEQSERVER_GROUP $SEQSERVER_BASE_PATH

#
#
# Install WorkQueue
cd ~/
curl -O http://ccl.cse.nd.edu/software/files/cctools-7.0.19-x86_64-centos7.tar.gz
tar -xvf cctools-7.0.19-x86_64-centos7.tar.gz
sudo cp cctools-7.0.19-x86_64-centos7/bin/* /usr/bin/
rm cctools-7.0.19-x86_64-centos7.tar.gz
which work_queue_worker

#
#
# Install BLAST
cd ~/
curl -O ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/LATEST/ncbi-blast-2.9.0+-x64-linux.tar.gz
tar -xvf ncbi-blast-2.9.0+-x64-linux.tar.gz
sudo cp ncbi-blast-2.9.0+/bin/* /usr/bin/
rm ncbi-blast-2.9.0+-x64-linux.tar.gz
which blastn

#
#
# Create directory for database, and change owner to current user
sudo mkdir -p /var/www/sequenceserver/db
sudo chown $SEQSERVER_USER:$SEQSERVER_GROUP /var/www/sequenceserver/db

#
# Download sample database
cd ~/
curl ftp://ftp.ncbi.nlm.nih.gov/blast/db/vector.tar.gz -O
sudo tar -xvf vector.tar.gz -C $SEQSERVER_DB_PATH/
rm ~/vector.tar.gz



#
#
# Setup iRODs
touch ~/password.txt
chmod 600 ~/password.txt
chown $SUDO_USER:root ~/password.txt
if [ $IRODS_USER != "anonymous" ]; then
    echo $IRODS_PASS > ~/password.txt
fi

touch $SEQSERVER_SYNC_PATH_FILE
sudo chown $SEQSERVER_USER:$SEQSERVER_GROUP $SEQSERVER_SYNC_PATH_FILE
sudo chmod o-rwx $SEQSERVER_SYNC_PATH_FILE
echo "$IRODS_SYNC_PATH" > $SEQSERVER_SYNC_PATH_FILE

#
# Setup iRODs seqserver
sudo -u $SEQSERVER_USER -H mkdir /home/$SEQSERVER_USER/.irods
echo "{ \"irods_zone_name\": \"iplant\", \"irods_host\": \"data.cyverse.org\", \"irods_port\": 1247, \"irods_user_name\": \"$IRODS_USER\" }" > /home/$SEQSERVER_USER/.irods/irods_environment.json
sudo chown $SEQSERVER_USER: /home/$SEQSERVER_USER/.irods/irods_environment.json
sudo -u $SEQSERVER_USER -H iinit < ~/password.txt
sudo -u $SEQSERVER_USER -H irsync -r i:$IRODS_SYNC_PATH $SEQSERVER_DB_PATH
irsync -r i:$IRODS_SYNC_PATH $SEQSERVER_DB_PATH


#
# Launch systemd service - db sync
cd ~/
git clone https://github.com/JLHonors/ACIC2019-Midterm.git
cd ~/ACIC2019-Midterm/deploy
sudo cp blast_db_sync.service /etc/systemd/system
sudo cp blast_db_sync.timer /etc/systemd/system
cp sync_blast_db.sh $SEQSERVER_BASE_PATH/
sudo chown $SEQSERVER_USER:$SEQSERVER_GROUP $SEQSERVER_BASE_PATH/sync_blast_db.sh
sudo chmod 750 $SEQSERVER_BASE_PATH/sync_blast_db.sh

#
# Launch systemd service - spwan worker
cd ~/ACIC2019-Midterm/deploy
sudo cp spawn_wq_worker.service /etc/systemd/system
sudo cp spawn_wq_worker.sh $SEQSERVER_BASE_PATH/spawn_wq_worker.sh
sudo chown $SEQSERVER_USER:$SEQSERVER_GROUP $SEQSERVER_BASE_PATH/spawn_wq_worker.sh
sudo touch $SEQSERVER_BASE_PATH/wq_password.txt
sudo chown $SEQSERVER_USER:$SEQSERVER_GROUP $SEQSERVER_BASE_PATH/wq_password.txt
sudo chmod 600 $SEQSERVER_BASE_PATH/wq_password.txt
echo $WORKQUEUE_PASSWORD > $SEQSERVER_BASE_PATH/wq_password.txt

sudo systemctl daemon-reload


#
# Start DB sync service and spawn worker service
sudo systemctl enable blast_db_sync.timer
sudo systemctl start blast_db_sync.timer
sudo systemctl enable spawn_wq_worker.service
sudo systemctl start spawn_wq_worker.service

#
#
sudo systemctl is-active blast_db_sync.timer
sudo systemctl is-active spawn_wq_worker.service > status

