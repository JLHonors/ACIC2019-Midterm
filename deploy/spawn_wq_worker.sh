#!/bin/bash

$MASTER_IP=$(cat /var/www/sequenceserver/master_ip.txt)
$MASTER_PORT=9123
/usr/bin/work_queue_worker $MASTER_IP $MASTER_PORT -P /var/www/sequenceserver/wq_password.txt