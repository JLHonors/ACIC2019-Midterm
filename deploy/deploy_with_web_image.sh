#!/bin/bash

#######################################################
#
# Use with image version 0.1
#
########################################################

WORKQUEUE_PASSWORD=VERY_VERY_VERY_STRONG_PASSWORD
IRODS_SYNC_PATH=/iplant/home/anonymous/db

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
SEQSERVER_SYNC_PATH_FILE=/var/www/sequenceserver/irods_sync_path.txt
SEQSERVER_NUM_PROCESS=1

if [ $WORKQUEUE_PASSWORD == "VERY_VERY_VERY_STRONG_PASSWORD" ]; then
    echo "Change WORKQUEUE_PASSWORD in script"
    exit -1
fi
if [ $IRODS_SYNC_PATH == "/iplant/home/anonymous/db" ]; then
    echo "Change IRODS_SYNC_PATH in script"
    exit -1
fi

#
# Save WQ password to file
sudo touch $SEQSERVER_BASE_PATH/wq_password.txt
sudo chown $SEQSERVER_USER:$SEQSERVER_GROUP $SEQSERVER_BASE_PATH/wq_password.txt
sudo chmod 600 $SEQSERVER_BASE_PATH/wq_password.txt
echo $WORKQUEUE_PASSWORD > $SEQSERVER_BASE_PATH/wq_password.txt


#
# Save sync path to file
touch $SEQSERVER_SYNC_PATH_FILE
sudo chown $SEQSERVER_USER:$SEQSERVER_GROUP $SEQSERVER_SYNC_PATH_FILE
sudo chmod o-rwx $SEQSERVER_SYNC_PATH_FILE
echo $IRODS_SYNC_PATH > $SEQSERVER_SYNC_PATH_FILE

#
# Login as anonymous user
iinit

#
# Restart the service
sudo systemctl restart blast_db_sync.service
sudo systemctl restart blast_db_sync.timer
sudo systemctl restart blast_workqueue.service
sudo systemctl restart nginx.service

