#!/bin/bash

# This is setup script for Redis server.

set -ex

if [ "$(id -u)" != "0" ]; then
	echo >&2 "Error: This script must be run as user 'root'";
	exit 1
fi

source $(dirname $0)/../helper.sh

timestamp () {
	date +"%F %T,%3N"
}

setuphost () {
	HOSTNAME=$(hostname)
	HOSTLOCAL="127.0.1.1"
	echo "$HOSTLOCAL $HOSTNAME" >> /etc/hosts
}

install_redis () {
	mkdir -p /home/ubuntu && cd /home/ubuntu

	apt-get update
	apt-get install -y redis-server  sysstat htop
	update-rc.d redis-server disable

	cp /etc/redis/redis.conf /etc/redis/redis.conf.backup

#	service redis-server restart
}

configure_redis () {
	verify_variable_set "CLOUD_REDISINCOMING"
	verify_variable_notempty "CLOUD_REDISINCOMING"
	
	#redisIP=${CLOUD_REDISINCOMING%:*}
	redisIP="0.0.0.0"
	redisPort=${CLOUD_REDISINCOMING#*:}
	
	sed -i "s/bind .*/bind ${redisIP}/" /etc/redis/redis.conf
	sed -i "s/port .*/port ${redisPort}/" /etc/redis/redis.conf
}

case "$1" in 
	install)
		echo "[$(timestamp)] ---- 1. Setup Host ----"
		setuphost
		echo "[$(timestamp)] ---- 2. Install Redis ----"
		install_redis
		#echo "[$(timestamp)] ---- 3. Install Redis Admin ----"
		#install_redis_admin
		;;
	configure)
		configure_redis
		;;
	start)
		#exec /usr/bin/redis-server
		service redis-server stop
		service redis-server start
		;;
	stop)
		;;
	startdetect)
		;;
	stopdetect)
		;;
	update)
		;;
esac

echo "[$(timestamp)] ---- Completed ----"


# echo "[$(timestamp)] ---- 4. Update IPTables rules ----"
# update_iptables
#
# echo "[$(timestamp)] ---- 5. Setting up JCatascopia Agent ----"
# setup_JCatascopiaAgent


exit 0
