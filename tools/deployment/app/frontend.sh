#!/bin/bash

# This is setup script for Frontend instance.

set -ex

if [ "$(id -u)" != "0" ]; then
	echo "Error: This script must be run as root" 1>&2
	exit 1
fi

DEST="/home/ubuntu/www"
APP="dataplay"
WWW="www-src"

HOST=$(ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}')

# LOADBALANCER_HOST="109.231.121.26"
LOADBALANCER_HOST=$(ss-get --timeout 360 loadbalancer.hostname)
LOADBALANCER_PORT="1937"

timestamp () {
	date +"%F %T,%3N"
}

setuphost () {
	HOSTNAME=$(hostname)
	HOSTLOCAL="127.0.1.1"
	echo "$HOSTLOCAL $HOSTNAME" >> /etc/hosts
}

export_variables () {
	echo "export DP_LOADBALANCER_HOST=$LOADBALANCER_HOST" >> /etc/profile.d/dataplay.sh
	echo "export DP_LOADBALANCER_PORT=$LOADBALANCER_PORT" >> /etc/profile.d/dataplay.sh

	. /etc/profile

	su - ubuntu -c ". /etc/profile"
}

install_nginx () {
	URL="https://raw.githubusercontent.com"
	USER="playgenhub"
	REPO="DataPlay"
	BRANCH="master"
	SOURCE="$URL/$USER/$REPO/$BRANCH"

	mkdir -p $DEST/$APP/$WWW/dist

	apt-add-repository -y ppa:nginx/stable && \
	apt-get update && \
	apt-get install -y nginx

	unixts="$(date +'%Y%m%d%H%M%S')"
	keyword="<filesystem>"
	destination="$DEST/$APP/$WWW/dist"

	cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.$unixts
	wget --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 0 -N $SOURCE/tools/deployment/app/nginx.default -O /etc/nginx/sites-available/default
	sed -i 's,'"$keyword"','"$destination"',g' /etc/nginx/sites-available/default

	chown ubuntu:www-data $DEST/$APP/$WWW

	service nginx reload
}

download_app () {
	URL="https://github.com"
	USER="playgenhub"
	REPO="DataPlay"
	BRANCH="master"
	SOURCE="$URL/$USER/$REPO"

	cd $DEST
	echo "Fetching latest ZIP"
	wget --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 0 -N $SOURCE/archive/$BRANCH.zip -O $BRANCH.zip
	echo "Extracting from $BRANCH.zip"
	unzip -oq $BRANCH.zip
	if [ -d $APP ]; then
		rm -r $APP
	fi
	mkdir -p $APP
	echo "Moving files from $REPO-$BRANCH/ to $APP"
	mv -f $REPO-$BRANCH/* $APP
	cd $APP
}

init_frontend () {
	sed -i "s/localhost:3000/$LOADBALANCER_HOST/g" $DEST/$APP/$WWW/dist/scripts/*.js
}

configure_frontend () {
	sed -i "s/localhost:3000/$LOADBALANCER_HOST/g" $DEST/$APP/$WWW/app/scripts/app.coffee

	command -v grunt >/dev/null 2>&1 || { echo >&2 "Error: Command 'grunt' not found!"; exit 1; }

	command -v coffee >/dev/null 2>&1 || { echo >&2 "Error: 'coffee' is not installed!"; exit 1; }

	command -v bower >/dev/null 2>&1 || { echo >&2 "Error: 'bower' is not installed!"; exit 1; }
}

build_frontend () {
	npm install -d
	bower install
	grunt build
}

echo "[$(timestamp)] ---- 1. Setup Host ----"
setuphost

echo "[$(timestamp)] ---- 2. Export Variables ----"
export_variables

echo "[$(timestamp)] ---- 3. Install Nginx ----"
install_nginx

echo "[$(timestamp)] ---- 4. Download Application ----"
download_app

# We either Init frontend which is quicker and doesn't install any extra libraries
# or do configure and build which is very time consuming process due to lots of node.js libraries
echo "[$(timestamp)] ---- 5. Init Frotnend ----"
init_frontend

# echo "[$(timestamp)] ---- 6. Configure Frotnend ----"
# configure_frontend

# echo "[$(timestamp)] ---- 7. Build Frontend ----"
# su ubuntu -c "$(typeset -f build_frontend); build_frontend" # Run function as user 'ubuntu'

echo "[$(timestamp)] ---- Completed ----"

exit 0