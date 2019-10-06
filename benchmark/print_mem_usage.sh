#!/bin/bash

if [ -z $1 ]
then
    >&2 echo "Error"
    >&2 echo "No BLAST binary specified, blastx, blastn, blastp"
    >&2 echo "e.g."
    >&2 echo "./print_mem_usage.sh blastn"
    exit
fi

was_running=0

while true
do
    running=$( ps -a | grep blastn )

    # if is NOT running
    if [ -z "$running" ]
    then
        if [ $was_running == 1 ] # if was running
        then
            was_running=0
            exit
        fi
    # if is running
    else
        if [ $was_running == 0 ]
        then
            was_running=1
        fi
        # If there are multiple instance (process) of the same executable running, only the first one(smaller pid) will be profiled
        ps -a | grep $1 | xargs | cut -d' ' -f1 | xargs -I {} pmap {} | grep total | xargs | cut -d' ' -f2
    fi
    sleep 0.1

done

