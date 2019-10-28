#!/bin/env bash

SYNC_PATH=$(cat /var/www/sequenceserver/irods_sync_path.txt)
irsync -r i:SYNC_PATH /var/www/sequenceserver/db

