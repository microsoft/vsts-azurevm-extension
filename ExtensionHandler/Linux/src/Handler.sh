#! /bin/bash

arg="$@"
logfile="/var/log/waagent.log"
cmnd3="/usr/bin/python3"
if [ -f "${cmnd3}" ]
then
    echo "`date`- ${cmnd3} path exists" >> $logfile
    ./AzureRM.py $arg
    exit $?
fi
cmnd2="/usr/bin/python"
if [ -f "${cmnd2}" ]
then
    echo "`date`- ${cmnd2} path exists" >> $logfile
    ./AzureRM_python2.py $arg
    exit $?
fi
./AzureRM.py $arg
