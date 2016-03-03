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

LOGFILENAME=frontend.log
LOGFILE=$LOGDIR/$LOGFILENAME

logsetup

verify_variable_set "CONTAINER_IP"
verify_variable_set "MasterNodeIncoming"
verify_variable_notempty "MasterNodeIncoming"

verify_variable_set "CLOUD_MasterNodeDatebase"
verify_variable_notempty "CLOUD_MasterNodeDatebase"

GO_VERSION="go1.4.3"
DEST="/home/ubuntu/www"
APP="dataplay"

export GOROOT=/home/ubuntu/go 
export PATH="$PATH:\$GOROOT/bin"

export GOPATH=/home/ubuntu/gocode
export PATH="PATH:GOPATH/bin"
#APP_HOST=$(ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}')
#APP_PORT="3000"
#APP_TYPE="master"

# DATABASE_HOST="109.231.121.13"
#DATABASE_HOST=$(ss-get --timeout 360 pgpool.hostname)
#DATABASE_PORT="9999"

# REDIS_HOST="109.231.121.13"
#REDIS_HOST=$(ss-get --timeout 360 redis.hostname)
#REDIS_PORT="6379"

# CASSANDRA_HOST="109.231.121.13"
#CASSANDRA_HOST=$(ss-get --timeout 360 cassandra.hostname)
#CASSANDRA_PORT="9042"

# LOADBALANCER_HOST="109.231.121.26"
#LOADBALANCER_HOST=$(ss-get --timeout 360 loadbalancer.hostname)
#LOADBALANCER_REQUEST_PORT="3000"
#LOADBALANCER_API_PORT="1937"

#JCATASCOPIA_REPO="109.231.126.62" # need to have a better repository for JCatascopia probes
#JCATASCOPIA_DASHBOARD="109.231.122.112" # now hardcoded, in future when Orchestrator deployed and running to get from Slipstream

timestamp () {
	date +"%F %T,%3N"
}

setuphost () {
	HOSTNAME=$(hostname)
	HOSTLOCAL="127.0.1.1"
	echo "$HOSTLOCAL $HOSTNAME" >> /etc/hosts
}

install_go () {
	apt-get install -y mercurial bzr

	mkdir -p /home/ubuntu && cd /home/ubuntu
	mkdir -p gocode && mkdir -p www

	wget --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 0 -N https://storage.googleapis.com/golang/$GO_VERSION.linux-amd64.tar.gz
	tar xf $GO_VERSION.linux-amd64.tar.gz

	echo "export GOROOT=/home/ubuntu/go" >> /etc/profile.d/dataplay.sh
	echo "PATH=\$PATH:\$GOROOT/bin" >> /etc/profile.d/dataplay.sh

	echo "export GOPATH=/home/ubuntu/gocode" >> /etc/profile.d/dataplay.sh
	echo "PATH=\$PATH:\$GOPATH/bin" >> /etc/profile.d/dataplay.sh

	# . /etc/profile
}

export_variables () {
	echo "export DP_LOADBALANCER_HOST=$LOADBALANCER_HOST" >> /etc/profile.d/dataplay.sh
	echo "export DP_LOADBALANCER_REQUEST_PORT=$LOADBALANCER_REQUEST_PORT" >> /etc/profile.d/dataplay.sh
	echo "export DP_LOADBALANCER_API_PORT=$LOADBALANCER_API_PORT" >> /etc/profile.d/dataplay.sh
	echo "export DP_DATABASE_HOST=$DATABASE_HOST" >> /etc/profile.d/dataplay.sh
	echo "export DP_DATABASE_PORT=$DATABASE_PORT" >> /etc/profile.d/dataplay.sh
	echo "export DP_REDIS_HOST=$REDIS_HOST" >> /etc/profile.d/dataplay.sh
	echo "export DP_REDIS_PORT=$REDIS_PORT" >> /etc/profile.d/dataplay.sh
	echo "export DP_CASSANDRA_HOST=$CASSANDRA_HOST" >> /etc/profile.d/dataplay.sh
	echo "export DP_CASSANDRA_PORT=$CASSANDRA_PORT" >> /etc/profile.d/dataplay.sh

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
	nohub $DEST/$APP/bin/$project > $LOG 2>&1&
	echo "Done! $ sudo tail -f $DEST/$APP/$LOG for more details"
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

#inform_loadbalancer () {
#	retries=0
#	until curl -H "Content-Type: application/json" -X POST -d "{\"ip\":\"$APP_HOST:$APP_PORT\"}" http://$LOADBALANCER_HOST:$LOADBALANCER_API_PORT/$APP_TYPE; do
#		echo "[$(timestamp)] Load Balancer is not up yet, retry... [$(( retries++ ))]"
#		sleep 5
#	done
#}

#update_iptables () {
#	# Accept direct connections to API
#	iptables -A INPUT -p tcp --dport 3000 -j ACCEPT # HTTP
#	iptables -A INPUT -p tcp --dport 3443 -j ACCEPT # HTTPS
#
#	iptables-save
#}

setup_service_script () {
	DEPLOYMENT="tools/deployment"
	SERVICE="master.service.sh"

	cp ${LOCAL_DIR}/../../deployment/app/$SERVICE $DEST/$SERVICE

	chmod +x $DEST/$SERVICE
}

#added to automate JCatascopiaAgent installation
#setup_JCatascopiaAgent(){
#	wget -q https://raw.githubusercontent.com/CELAR/celar-deployment/master/vm/jcatascopia-agent.sh
#
#	wget -q http://$JCATASCOPIA_REPO/JCatascopiaProbes/DataPlayProbe.jar
#	mv ./DataPlayProbe.jar /usr/local/bin/
#
#	bash ./jcatascopia-agent.sh > /tmp/JCata.txt 2>&1
#
#	echo "probes_external=DataPlayProbe,/usr/local/bin/DataPlayProbe.jar" | sudo -S tee -a /usr/local/bin/JCatascopiaAgentDir/resources/agent.properties
#	eval "sed -i 's/server_ip=.*/server_ip=$JCATASCOPIA_DASHBOARD/g' /usr/local/bin/JCatascopiaAgentDir/resources/agent.properties"
#
#	/etc/init.d/JCatascopia-Agent restart > /tmp/JCata.txt 2>&1
#
#	rm ./jcatascopia-agent.sh
#}

case "$1" in
	install)
		echo "[$(timestamp)] ---- 1. Setup Host ----"
		setuphost
		echo "[$(timestamp)] ---- 2. Install GO ----"
		install_go
		# echo "[$(timestamp)] ---- 3. Export Variables ----"
		#export_variables
		install_master_server
		;;
	configure)
		echo "[$(timestamp)] ---- 4. Run API (Master) Server ----"
		kill_master_servers
	;;
	start)
		kill_master_servers
		#run_master_server
		#service nginx start
		sleep infinity 
		;;
	stop)
		kill_master_servers
		service nginx stop
		kill -9 1
		;;
		# echo "[$(timestamp)] ---- 5. Inform Load Balancer (Add) ----"
		# inform_loadbalancer
	updateports)
		;;
		# echo "[$(timestamp)] ---- 6. Update IPTables rules ----"
		# update_iptables
esac

echo "[$(timestamp)] ---- 7. Setup Service Script ----"
setup_service_script

# echo "[$(timestamp)] ---- 8. Setting up JCatascopia Agent ----"
# setup_JCatascopiaAgent

echo "[$(timestamp)] ---- Completed ----"

exit 0
