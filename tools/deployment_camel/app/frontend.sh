#!/bin/bash

# This is setup script for Frontend instance.

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

DEST="/home/ubuntu/www"
APP="dataplay"
WWW="www-src"

check_variables () {
	verify_variable_set "CONTAINER_IP"
	verify_variable_set "PUBLIC_FrontendNodeLogic"
	verify_variable_set "CLOUD_FRONTENDNODEINCOMING"
	verify_variable_notempty "CONTAINER_IP"
	verify_variable_notempty "CLOUD_FRONTENDNODEINCOMING"
	## this is my outgoing port; it is the same as the global port ##
	verify_variable_notempty "PUBLIC_FrontendNodeLogic"
	
	DOMAIN=$PUBLIC_FrontendNodeLogic
}

#APP_HOST=$(ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}')
#APP_PORT=$CLOUD_FrontendIncoming
#APP_TYPE="gamification"

# LOADBALANCER_HOST="109.231.121.26"
# LOADBALANCER_HOST=$(ss-get --timeout 360 loadbalancer.hostname)
# LOADBALANCER_REQUEST_PORT="80"
# LOADBALANCER_API_PORT="1937"

# "localhost:$APP_PORT"
# DOMAIN="dataplay.playgen.com"
# DOMAIN="${LOADBALANCER_HOST}:${LOADBALANCER_REQUEST_PORT}"

#JCATASCOPIA_REPO="109.231.126.62"
#JCATASCOPIA_DASHBOARD="109.231.122.112"

timestamp () {
	date +"%F %T,%3N"
}

setuphost () {
	HOSTNAME=$(hostname)
	HOSTLOCAL="127.0.1.1"
	echo "$HOSTLOCAL $HOSTNAME" >> /etc/hosts
}

#export_variables () {
#	echo "export DP_LOADBALANCER_HOST=$LOADBALANCER_HOST" >> /etc/profile.d/dataplay.sh
#	echo "export DP_LOADBALANCER_REQUEST_PORT=$LOADBALANCER_REQUEST_PORT" >> /etc/profile.d/dataplay.sh
#	echo "export DP_LOADBALANCER_API_PORT=$LOADBALANCER_API_PORT" >> /etc/profile.d/dataplay.sh
#	echo "export DP_DOMAIN=$DOMAIN" >> /etc/profile.d/dataplay.sh
#
#	. /etc/profile
#
#	su - ubuntu -c ". /etc/profile"
#}

install_nginx () {
	URL="https://raw.githubusercontent.com"
	USER="playgenhub"
	REPO="DataPlay"
	BRANCH="master"
	SOURCE="$URL/$USER/$REPO/$BRANCH"

	mkdir -p $DEST/$APP/$WWW/dist

	apt-add-repository -y ppa:nginx/stable
	apt-get update
	apt-get install -y nginx-full unzip sysstat htop

	unixts="$(date +'%Y%m%d%H%M%S')"
	keyword="<filesystem>"
	destination="$DEST/$APP/$WWW/dist"

	cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.$unixts
	#wget --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 0 -N $SOURCE/tools/deployment/app/nginx.default -O /etc/nginx/sites-available/default
	cp $LOCAL_DIR/nginx.default /etc/nginx/sites-available/default
	sed -i 's,'"$keyword"','"$destination"',g' /etc/nginx/sites-available/default

	chown -R www-data:www-data $DEST

	service nginx stop
	update-rc.d nginx disable
}

download_app () {
	URL="https://codeload.github.com"
	USER="playgenhub"
	REPO="DataPlay"
	BRANCH="master"
	SOURCE="$URL/$USER/$REPO"
	
	rm -rf $DEST/$APP
	mkdir -p $DEST/$APP
	cp -r $LOCAL_DIR/../../../www-src $DEST/$APP

	# cd $DEST
	# echo "Fetching latest ZIP"
	# wget --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 0 -N $SOURCE/zip/$BRANCH -O $BRANCH.zip
	# echo "Extracting from $BRANCH.zip"
	# unzip -oq $BRANCH.zip
	# if [ -d $APP ]; then
	#	rm -r $APP
	# fi
	# mkdir -p $APP
	# echo "Moving files from here to webdir"
 	# mv -f $REPO-$BRANCH/* $APP
	# cd $APP
}

init_frontend () {
	sed -i "s/localhost:3000/$DOMAIN/g" $DEST/$APP/$WWW/dist/scripts/*.js
}

configure_frontend () {
	sed -i "s/localhost:3000/$DOMAIN/g" $DEST/$APP/$WWW/app/scripts/app.coffee

	command -v grunt >/dev/null 2>&1 || { echo >&2 "Error: Command 'grunt' not found!"; exit 1; }

	command -v coffee >/dev/null 2>&1 || { echo >&2 "Error: 'coffee' is not installed!"; exit 1; }

	command -v bower >/dev/null 2>&1 || { echo >&2 "Error: 'bower' is not installed!"; exit 1; }
}

build_frontend () {
	npm install -d
	bower install
	grunt build
}

#inform_loadbalancer () {
#	retries=0
#	until curl -H "Content-Type: application/json" -X POST -d "{\"ip\":\"$APP_HOST:$APP_PORT\"}" http://$LOADBALANCER_HOST:$LOADBALANCER_API_PORT/$APP_TYPE; do
#		echo "[$(timestamp)] Load Balancer is not up yet, retry... [$(( retries++ ))]"
#		sleep 5
#	done
#}

setup_service_script () {
	DEPLOYMENT="tools/deployment"
	SERVICE="frontend.service.sh"

	cp $LOCAL_DIR/$SERVICE $DEST/$SERVICE

	chmod +x $DEST/$SERVICE
}

#added to automate JCatascopiaAgent installation
#setup_JCatascopiaAgent(){
#	wget -q https://raw.githubusercontent.com/CELAR/celar-deployment/master/vm/jcatascopia-agent.sh
#
#	bash ./jcatascopia-agent.sh > /tmp/JCata.txt 2>&1
#
#	eval "sed -i 's/server_ip=.*/server_ip=$JCATASCOPIA_DASHBOARD/g' /usr/local/bin/JCatascopiaAgentDir/resources/agent.properties"
#
#	/etc/init.d/JCatascopia-Agent restart > /tmp/JCata.txt 2>&1
#
#	rm ./jcatascopia-agent.sh
#}

## FIXME: use configured port
case "$1" in
	install)
		echo "[$(timestamp)] ---- 1. Setup Host ----"
		setuphost
		# echo "[$(timestamp)] ---- 2. Export Variables ----"
		# export_variables
		echo "[$(timestamp)] ---- 3. Install Nginx ----"
		install_nginx
		echo "[$(timestamp)] ---- 4. Download Application ----"
		download_app
		# We either Init frontend which is quicker and doesn't install any extra libraries
		# or do configure and build which is very time consuming process due to lots of node.js libraries
		;;
	configure)
		check_variables
		echo "[$(timestamp)] ---- 5. Init Frotnend ----"
		init_frontend
		## echo "[$(timestamp)] ---- 6. Configure Frotnend ----"
		## configure_frontend
		## echo "[$(timestamp)] ---- 7. Build Frontend ----"
		## su ubuntu -c "$(typeset -f build_frontend); build_frontend" # Run function as user 'ubuntu'
		## echo "[$(timestamp)] ---- 6. Inform Load Balancer (Add) ----"
		## inform_loadbalancer
		echo "[$(timestamp)] ---- 7. Setup Service Script ----"
		setup_service_script
		;;
	start)
		service nginx start
		;;
	stop)
		service nginx stop
		;;
	startdetect)
		;;
	stopdetect)
		;;
	updateports)
		check_variables
		init_frontend
		configure_frontend
		service nginx restart
		;;
esac

echo "[$(timestamp)] ---- Completed ----"

exit 0
