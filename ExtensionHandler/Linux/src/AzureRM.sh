#!/bin/bash

arg="$@"
logfile="/var/log/waagent.log"
cmnd="/usr/bin/python3"
if [ -f "${cmnd}" ]
then
    echo "`date`- ${cmnd} path exists" >> $logfile
    AzureRM.py $arg
    exit $?
fi
cmnd="/usr/bin/python"
if [ -f "${cmnd}" ]
then
    echo "`date`- ${cmnd} path exists" >> $logfile
    cd python2 && AzureRM.py $arg
    exit $?
fi
exit 0