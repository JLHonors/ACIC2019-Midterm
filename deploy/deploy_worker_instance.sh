#!/bin/bash

IRODS_USER=YOUR_USERNAME
IRODS_PASS=YOUR_PASSWORD

MASTER_IP=XX.XX.XX.XX
MOST_WORKERS=4
LEAST_WORKERS=2
CORE_PER_WORKER=2
MEM_PER_WORKER=8

IRODS_GROUP=iplant-everyone

#######################################################
#
# DO NOT Modify anything below this
#
#######################################################

if [ -z $SUDO_USER ]; then
    echo "Need to run the script as sudo"
    exit -1
fi
if [ "$IRODS_USER" == "YOUR_USERNAME" ]; then
    echo "Change IRODS_USER in script"
    exit -1
fi
if [ "$IRODS_PASS" == "YOUR_PASSWORD" ]; then
    echo "Change IRODS_PASS in script"
    exit -1
fi
if [ "$MASTER_IP" == "XX.XX.XX.XX" ]; then
    echo "Change MASTER_IP in script"
    exit -1
fi

#
#
# Update & Upgrade
sudo apt update -y

#
#
# Install with apt
sudo apt install -y wget curl

#
#
# Store IP of WQ master into file
cd ~/
touch ~/master_ip.txt
chmod 640 ~/master_ip.txt
echo $MASTER_IP > ~/master_ip.txt

#
#
# Install WorkQueue
cd ~/
curl -O http://ccl.cse.nd.edu/software/files/cctools-7.0.19-x86_64-centos7.tar.gz
tar -xvf cctools-7.0.19-x86_64-centos7.tar.gz
sudo cp cctools-7.0.19-x86_64-centos7/bin/* /usr/bin/
rm cctools-7.0.19-x86_64-centos7.tar.gz

#
#
# Install BLAST
cd ~/
curl -O ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/LATEST/ncbi-blast-2.9.0+-x64-linux.tar.gz
tar -xvf ncbi-blast-2.9.0+-x64-linux.tar.gz
sudo cp ncbi-blast-2.9.0+/bin/* /usr/bin/
rm ncbi-blast-2.9.0+-x64-linux.tar.gz

#
#
# Create directory for database, and change owner to current user
sudo mkdir -p /var/www/sequenceserver/db
sudo chown $SUDO_USER:$IRODS_GROUP /var/www/sequenceserver/db

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
echo $IRODS_PASS > ~/password.txt
mkdir -p ~/.irods/
echo "{ \"irods_zone_name\": \"iplant\", \"irods_host\": \"data.cyverse.org\", \"irods_port\": 1247, \"irods_user_name\": \"$IRODS_USER\" }" > ~/.irods/irods_environment.json
iinit < ~/password.txt
irsync -r i:/iplant/home/$IRODS_USER/db /var/www/sequenceserver/db

#
# Launch work_queue_factory to spawn workers
work_queue_factory $MASTER_IP 9123 -T wq -w $LEAST_WORKERS -W $MOST_WORKERS --cores=$CORE_PER_WORKER --memory=$MEM_PER_WORKER
