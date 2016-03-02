#! /bin/bash

#Loging functions
function logsetup() {
        if [ ! -d $LOGDIR ]; then
                mkdir -p $LOGDIR
        fi
        if [ ! -f $LOGFILE ]; then
                touch $LOGFILE
        fi
}

function log() {
        echo "$*"
        echo "[$(date)]: $*" >> $LOGFILE
}


function verify_variable_set() {
# $1 contains the variable name
NAME=$1

# attempting to set local ip
if [ -z ${!NAME+123} ] ; then 
        MESSAGE="Environment variable $1 required, but not set."
        log $MESSAGE
        exit 3
fi 
}

function verify_variable_notempty() {
# $1 contains the variable name
NAME=$1

if [ -z ${!NAME} ] ; then
 MESSAGE="Environment variable $1 required, but not set to reasonable value."
 log $MESSAGE
 exit 4
fi
}
