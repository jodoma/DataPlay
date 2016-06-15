#!/bin/bash

# This is setup script for PostreSQL Cluster server.

set -ex

source $(dirname $0)/../helper.sh

if [ "$(id -u)" != "0" ]; then
	echo >&2 "Error: This script must be run as user 'root'";
	exit 1
fi

timestamp () {
	date +"%F %T,%3N"
}

setuphost () {
	HOSTNAME=$(hostname)
	HOSTLOCAL="127.0.1.1"
	echo "$HOSTLOCAL $HOSTNAME" >> /etc/hosts
}

install_pgpool () {
	apt-get update
	apt-get install -y pgpool2 sysstat htop
	
	cp /etc/pgpool-II-94/pcp.conf.sample /etc/pgpool-II-94/pcp.conf
	echo "$DB_USER:`pg_md5 $DB_PASSWORD`" >> /etc/pgpool-II-94/pcp.conf

	cp /etc/pgpool-II-94/pool_hba.conf.sample /etc/pgpool-II-94/pool_hba.conf
	echo "host    all         all         0.0.0.0/0             md5" >> /etc/pgpool-II-94/pool_hba.conf

	pg_md5 -m -u $DB_USER $DB_PASSWORD # Generate pool_passwd

	systemctl restart pgpool-II-94
	systemctl enable pgpool-II-94
}

setup_pgpool () {
	DB_USER="playgen"
	DB_PASSWORD="aDam3ntiUm"
	DB_VERSION="9.4"

	verify_variable_set "PUBLIC_PGPOOLINCOMING"
	verify_variable_notempty "PUBLIC_PGPOOLINCOMING"

	cat /root/DataPlay/tools/deployment_camel/db/pgpool.conf > /etc/pgpool2/pgpool.conf

	# INJECT PASSWORD
	pg_md5 -m -f /etc/pgpool2/pgpool.conf -u $DB_USER $DB_PASSWORD
	chmod 660 /etc/pgpool2/pool_passwd
	chgrp postgres /etc/pgpool2/pool_passwd

	# create config file, with postgres instances
	verify_variable_set "CLOUD_PgPoolDownstream"
	config_nodes=""
	counter=0
	if [ -z ${CLOUD_PgPoolDownstream} ] ; then 
		echo "no postgres instances available"
	else 
	    arr=$(echo $CLOUD_PgPoolDownstream | tr "," "\n")
	    for x in $arr; do
			ip=${x%:*}
			port=${x#*:}
			config_nodes=$config_nodes"
				backend_hostname${counter} = '${ip}'
				backend_port${counter} = ${port}
				backend_weight${counter} = 1
				backend_data_directory${counter} = '/var/lib/postgresql/9.4/main/'
				backend_flag${counter} = 'ALLOW_TO_FAILOVER'"
			counter=$((counter+1))
		done
	fi

	echo $config_nodes >> /etc/pgpool2/pgpool.conf
	# set port
	echo "port = ${PUBLIC_PGPOOLINCOMING}" >> /etc/pgpool2/pgpool.conf	
	
}


case "$1" in
        install)
		echo "[$(timestamp)] ---- 1. Setup Host ----"
		setuphost
		echo "[$(timestamp)] ---- 2. Install pgpool-II ----"
		install_pgpool
		;;
	configure)
		echo "[$(timestamp)] ---- 3. Setup pgpool-II ----"
		setup_pgpool
		#echo "[$(timestamp)] ---- 4. Restart pgpool-II ----"
		#service pgpool2 restart
		;;
	start)
		service pgpool2 stop
		service pgpool2 start
		#sleep infinity
		;;
	stop)
		service pgpool2 stop
		;;
	startdetect)
                ;;
        stopdetect)
                ;;
        updateports)
		service pgpool2 stop
		setup_pgpool
		service pgpool2 start		
                ;;
esac

echo "[$(timestamp)] ---- Completed ----"

exit 0
