#!/bin/bash

IRODS_USER=anonymous
IRODS_PASS=YOUR_PASSWORD

WORKQUEUE_PASSWORD=VERY_VERY_VERY_STRONG_PASSWORD

MASTER_IP=XX.XX.XX.XX
MOST_WORKERS=4
LEAST_WORKERS=2
CORE_PER_WORKER=2
MEM_PER_WORKER=8

# e.g. /iplant/home/your_username/db
IRODS_SYNC_PATH=/iplant/home/$IRODS_USER/db

IRODS_GROUP=iplant-everyone

#######################################################
#
# DO NOT Modify anything below this
#
#######################################################

SEQSERVER_USER=seqserver
SEQSERVER_GROUP=seqserver_grou
SEQSERVER_BASE_PATH=/var/www/sequenceserver
SEQSERVER_DB_PATH=/var/www/sequenceserver/db
SEQSERVER_SYNC_PATH_FILE=/var/www/sequenceserver/irods_sync_path.txt

if [ $USER != "root" ]; then
    if [ -z $SUDO_USER ]; then
        echo "Need to run the script as sudo"
        exit -1
    fi
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
# Create user
sudo addgroup $SEQSERVER_GROUP
sudo adduser --quiet --disabled-login --gecos 'SequenceServer' $SEQSERVER_USER
sudo adduser $SEQSERVER_USER $SEQSERVER_GROUP
if [ -z $SUDO_USER ]; then
    sudo adduser $SUDO_USER $SEQSERVER_GROUP
fi

#
#
# Store IP of WQ master into file
cd ~/
touch $SEQSERVER_BASE_PATH/master_ip.txt
chmod 640 $SEQSERVER_BASE_PATH/master_ip.txt
echo $MASTER_IP > $SEQSERVER_BASE_PATH/master_ip.txt

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
sudo chown $seqserver:$seqserver /var/www/sequenceserver/db

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

mkdir -p ~/.irods/
echo "{ \"irods_zone_name\": \"iplant\", \"irods_host\": \"data.cyverse.org\", \"irods_port\": 1247, \"irods_user_name\": \"$IRODS_USER\" }" > ~/.irods/irods_environment.json

#
# Setup iRODs seqserver
sudo -u $SEQSERVER_USER -H mkdir /home/$SEQSERVER_USER/.irods
sudo cp ~/.irods/irods_environment.json /home/$SEQSERVER_USER/.irods/
sudo chown $SEQSERVER_USER: /home/$SEQSERVER_USER/.irods/irods_environment.json
sudo -u $SEQSERVER_USER -H iinit < ~/password.txt
sudo -u $SEQSERVER_USER -H irsync -r i:$IRODS_SYNC_PATH $SEQSERVER_DB_PATH

#
# Launch systemd service
cd ~/ACIC2019-Midterm/deploy
echo "User=$SEQSERVER_USER" >> blast_db_sync.service
sudo cp blast_db_sync.service /etc/systemd/system
sudo cp blast_db_sync.timer /etc/systemd/system
sudo cp spawn_wq_worker.service /etc/systemd/system
sudo touch $SEQSERVER_BASE_PATH/wq_password.txt
sudo chown $SEQSERVER_USER:$SEQSERVER_GROUP $SEQSERVER_BASE_PATH/wq_password.txt
sudo chmod 600 $SEQSERVER_BASE_PATH/wq_password.txt
echo $WORKQUEUE_PASSWORD > $SEQSERVER_BASE_PATH/wq_password.txt
cp sync_blast_db.sh $SEQSERVER_BASE_PATH/
sudo chown $SEQSERVER_USER:$SEQSERVER_GROUP $SEQSERVER_BASE_PATH/sync_blast_db.sh
sudo chmod 750 $SEQSERVER_BASE_PATH/sync_blast_db.sh
sudo systemctl daemon-reload


#
# Start DB sync service and spawn worker service
sudo systemctl enable blast_db_sync.timer
sudo systemctl start blast_db_sync.timer
sudo systemctl enable spawn_wq_worker.service
sudo systemctl start spawn_wq_worker.service
#work_queue_factory $MASTER_IP 9123 -T wq -w $LEAST_WORKERS -W $MOST_WORKERS --cores=$CORE_PER_WORKER --memory=$MEM_PER_WORKER
