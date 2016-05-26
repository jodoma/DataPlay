#!/bin/bash

# This is setup script for Master instance.

set -ex

source $(dirname $0)/../helper.sh

if [ "$(id -u)" != "0" ]; then
        LOGDIR=${PWD}/var/log/dataplay
        #PROJECTDIR=/opt/dataplay
else
        LOGDIR=/var/log/dataplay
        #PROJECTDIR=/opt/dataplay
fi

LOCAL_DIR=$(dirname $0)

LOGFILENAME=master.log
LOGFILE=$LOGDIR/$LOGFILENAME
DP_DATABASE_MAXIDLECONNS=8
DP_DATABASE_MAXOPENCONNS=512

# TODO is this correct?
export DP_DATABASE_MAXOPENCONNS
export DP_DATABASE_MAXIDLECONNS

logsetup

check_variables () {
	#provided communication MasterNodeIncoming { port: 2181 } // the local incoming port //
	#required communication MasterNodePostgres { port: 5432 mandatory } // connection to the Database (or PgPool) MANDATORY
	#required communication MasterNodeRedis { port: 1234 mandatory } // connection to the Redis  MANDATORY
	#required communication MasterNodeCassandra { port: 1234 mandatory } // connection to the Cassandra  MANDATORY
	verify_variable_set "CONTAINER_IP"
	verify_variable_set "MasterNodeIncoming"
	verify_variable_notempty "MasterNodeIncoming"
}

GO_VERSION="go1.4.3"
DEST="/home/ubuntu/www"
APP="dataplay"

export GOROOT=/home/ubuntu/go
export PATH="$PATH:$GOROOT/bin"

export GOPATH=/home/ubuntu/gocode
export PATH="$PATH:$GOPATH/bin"

timestamp () {
	date +"%F %T,%3N"
}

setuphost () {
	HOSTNAME=$(hostname)
	HOSTLOCAL="127.0.1.1"
	echo "$HOSTLOCAL $HOSTNAME" >> /etc/hosts
}

install_go () {
	apt-get install -y mercurial bzr sysstat htop

	mkdir -p /home/ubuntu && cd /home/ubuntu
	mkdir -p gocode && mkdir -p www

	wget -a /var/log/camel.wget.log -d --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 0 -N https://storage.googleapis.com/golang/$GO_VERSION.linux-amd64.tar.gz
	tar xzvf $GO_VERSION.linux-amd64.tar.gz

	echo "export GOROOT=/home/ubuntu/go" >> /etc/profile.d/dataplay.sh
	echo "PATH=\$PATH:\$GOROOT/bin" >> /etc/profile.d/dataplay.sh

	echo "export GOPATH=/home/ubuntu/gocode" >> /etc/profile.d/dataplay.sh
	echo "PATH=\$PATH:\$GOPATH/bin" >> /etc/profile.d/dataplay.sh

	# . /etc/profile
}

export_variables () {
	verify_variable_set "CLOUD_MasterNodePgPool"
	verify_variable_notempty "CLOUD_MasterNodePgPool"
	pgIP=${CLOUD_MasterNodePgPool%:*}
	pgPort=${CLOUD_MasterNodePgPool#*:}

	verify_variable_set "CLOUD_MasterNodeRedis"
	verify_variable_notempty "CLOUD_MasterNodeRedis"
	redisIP=${CLOUD_MasterNodeRedis%:*}
	redisPort=${CLOUD_MasterNodeRedis#*:}

	verify_variable_set "CLOUD_MasterNodeCassandra"
	verify_variable_notempty "CLOUD_MasterNodeCassandra"
	cassandraIP=${CLOUD_MasterNodeCassandra%:*}
	cassandraPort=${CLOUD_MasterNodeCassandra#*:}


	#echo "export DP_LOADBALANCER_HOST=$LOADBALANCER_HOST" >> /etc/profile.d/dataplay.sh
	#echo "export DP_LOADBALANCER_REQUEST_PORT=$LOADBALANCER_REQUEST_PORT" >> /etc/profile.d/dataplay.sh
	#echo "export DP_LOADBALANCER_API_PORT=$LOADBALANCER_API_PORT" >> /etc/profile.d/dataplay.sh
	echo "export DP_DATABASE_HOST=$pgIP" >> /etc/profile.d/dataplay.sh
	echo "export DP_DATABASE_PORT=$pgPort" >> /etc/profile.d/dataplay.sh
	echo "export DP_REDIS_HOST=$redisIP" >> /etc/profile.d/dataplay.sh
	echo "export DP_REDIS_PORT=$redisPort" >> /etc/profile.d/dataplay.sh
	echo "export DP_CASSANDRA_HOST=$cassandraIP" >> /etc/profile.d/dataplay.sh
	echo "export DP_CASSANDRA_PORT=$cassandraPort" >> /etc/profile.d/dataplay.sh
	echo "export DP_DATABASE_MAXIDLECONNS=$DP_DATABASE_MAXIDLECONNS" >> /etc/profile.d/dataplay.sh
	echo "export DP_DATABASE_MAXOPENCONNS=$DP_DATABASE_MAXOPENCONNS" >> /etc/profile.d/dataplay.sh

	. /etc/profile

	su - ubuntu -c ". /etc/profile"
}

install_master_server() {
	rm -rf $DEST/$APP
	mkdir $DEST/$APP
	cp -r ${LOCAL_DIR}/../../../src $DEST/$APP
	cp -r ${LOCAL_DIR}/../../../start.sh $DEST/$APP
	cd $DEST/$APP
	echo 'BUILDING GOGRAM'
	oldgo=$GOPATH
	if [[ "$OSTYPE" == "msys" ]]; then
	        GOPATH=$oldgo";"$(pwd -W)
	else
	        GOPATH=$oldgo:$(pwd)
	fi
	export GOPATH
	project=dataplay
	go get -v $project
	go install -v $project
	export GOPATH=$oldgo
}

kill_master_servers() {
	# Kill any running process
	if ps ax | grep -v grep | grep $APP > /dev/null; then
		echo "SHUTDOWN RUNING APP..."
		killall -9 $APP
	fi
}

start_master_server() {
	echo 'BUILDING GOGRAM'
	oldgo=$GOPATH
	if [[ "$OSTYPE" == "msys" ]]; then
	        GOPATH=$oldgo";"$(pwd -W)
	else
	        GOPATH=$oldgo:$(pwd)
	fi
	export GOPATH
	project=dataplay
	nohup $DEST/$APP/bin/$project > $LOGFILE 2>&1&
	echo "Done! $ sudo tail -f $LOGFILE for more details"
}

#run_master_server () {
#	URL="https://codeload.github.com"
#	USER="playgenhub"
#	REPO="DataPlay"
#	BRANCH="master"
#	SOURCE="$URL/$USER/$REPO"
#
#	START="start.sh"
#	LOG="output.log"
#

#	cd $DEST
#	echo "Fetching latest ZIP"
#	wget --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 0 -N $SOURCE/zip/$BRANCH -O $BRANCH.zip
#	echo "Extracting from $BRANCH.zip"
#	unzip -oq $BRANCH.zip
#	if [ -d $APP ]; then
#		rm -r $APP
#	fi
#	mkdir -p $APP
#	echo "Moving files from $REPO-$BRANCH/ to $APP"
#	mv -f $REPO-$BRANCH/* $APP
#	cd $APP
#	chmod u+x $START
#	echo "Starting $APP_TYPE"
#	nohup sh $START > $LOG 2>&1&
#	echo "Done! $ sudo tail -f $DEST/$APP/$LOG for more details"
#}


case "$1" in
	install)
		echo "[$(timestamp)] ---- 1. Setup Host ----"
		setuphost
		echo "[$(timestamp)] ---- 2. Install GO ----"
		install_go
		echo "[$(timestamp)] ---- 3. Install (Master) Server ----"
		install_master_server
		;;
	configure)
		check_variables
		echo "[$(timestamp)] ---- 4. Kill (Master) Server ----"
		kill_master_servers
		echo "[$(timestamp)] ---- 5. Export Variables ----"
		export_variables
		#echo "[$(timestamp)] ---- 6. Setup Service Script ----"
		#setup_service_script
	;;
	start)
		check_variables
		kill_master_servers
		export_variables
		start_master_server
		#sleep infinity 
		;;
	stop)
		kill_master_servers
		#kill -9 1
		;;
	updateports)
		check_variables
		kill_master_servers
		export_variables
		start_master_server
		;;

esac

echo "[$(timestamp)] ---- Completed ----"

exit 0
