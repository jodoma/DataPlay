#!/bin/bash

# This is setup script for PostreSQL Cluster server.

set -ex

source $(dirname $0)/../helper.sh
source $(dirname $0)/auth.inc.sh

if [ "$(id -u)" != "0" ]; then
	echo >&2 "Error: This script must be run as user 'root'";
	exit 1
fi

#DB_USER="playgen"
#DB_PASSWORD="aDam3ntiUm"
#DB_VERSION="9.4"


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

        sed -i 's/^#$ModLoad imudp/$ModLoad imudp/g' /etc/rsyslog.conf
        sed -i 's/^#$UDPServerRun 514/$UDPServerRun 514/g' /etc/rsyslog.conf
        sed -i 's/^#$ModLoad imtcp/$ModLoad imtcp/g' /etc/rsyslog.conf
        sed -i 's/^#$InputTCPServerRun 514/$InputTCPServerRun 514/g' /etc/rsyslog.conf
        echo "local0.*                                                /var/log/pgpool.log" >> /etc/rsyslog.conf

        service rsyslog restart
        # cp /etc/pgpool-II-94/pool_hba.conf.sample /etc/pgpool-II-94/pool_hba.conf
        echo "host    all         all         0.0.0.0/0             md5" >> /etc/pgpool2/pool_hba.conf
	echo "$DB_USER:$(pg_md5 $DB_PASSWORD)" >> /etc/pgpool2/pcp.conf
        pg_md5 -m -u $DB_USER $DB_PASSWORD # Generate pool_passwd
        chmod 660 /etc/pgpool2/pool_passwd
        chgrp postgres /etc/pgpool2/pool_passwd

        service pgpool2 restart
        #service pgpool2 stop
}

setup_pgpool () {
        verify_variable_set "PUBLIC_PGPOOLINCOMING"
        verify_variable_notempty "PUBLIC_PGPOOLINCOMING"

        cat /root/DataPlay/tools/deployment_camel/db/pgpool.conf > /etc/pgpool2/pgpool.conf
        # cp /etc/pgpool-II-94/pcp.conf.sample /etc/pgpool-II-94/pcp.conf
        echo "$DB_USER:`pg_md5 $DB_PASSWORD`" > /etc/pgpool2/pcp.conf

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

	echo "$config_nodes" >> /etc/pgpool2/pgpool.conf
	# set port
	echo "port = ${PUBLIC_PGPOOLINCOMING}" >> /etc/pgpool2/pgpool.conf	
	
}

import_data () {
	#Only import data if dataset is empty
	psql -h $DB_HOST -p ${PUBLIC_PGPOOLINCOMING} -U $DB_USER -l | cut -d '|' -f 1 | grep -qw $DB_NAME
	if [[ "$?" == "0" ]]; then
		return;
	fi

	set -ex
	MAX_RETRIES="200"

	LASTDATE=$(date +%Y-%m-%d) # Today
	BACKUP_DIR="postgresql/$LASTDATE-daily"
	BACKUP_FILE="$DB_NAME.sql.gz"

	i="1"
	if [[ $i -ge $MAX_RETRIES ]]; then
		echo >&2 "Error: Unable to fetch '$BACKUP_FILE' from backup server."; exit 1;
	fi
	until axel -a "http://$BACKUP_USER:$BACKUP_PASS@$BACKUP_HOST:$BACKUP_PORT/$BACKUP_DIR/$BACKUP_FILE"; do
		LASTDATE=$(date +%Y-%m-%d --date="$LASTDATE -1 days") # Decrement by 1 Day
		BACKUP_DIR="postgresql/$LASTDATE-daily"
		echo "Latest backup not available, try fetching $LASTDATE"
		i=$[$i+1]
	done

	gunzip -vk $BACKUP_FILE
	createdb -h $DB_HOST -p ${PUBLIC_PGPOOLINCOMING} -U $DB_USER -O $DB_USER $DB_NAME
	psql -h $DB_HOST -p ${PUBLIC_PGPOOLINCOMING} -U $DB_USER -d $DB_NAME -f $DB_NAME.sql
}

online_recovery(){
	NODE_COUNT=$(/usr/sbin/pcp_node_count 0 127.0.0.1 9898 $DB_USER $DB_PASSWORD);
	for node in $(seq 0 $((NODE_COUNT-1))); do
		NODE_STATE=$(/usr/sbin/pcp_node_info 0 127.0.0.1 9898 $DB_USER $DB_PASSWORD $node | cut -d" " -f3);
		# States: 
		# 0 - This state is only used during the initialization. PCP will never display it.
		# 1 - Node is up. No connections yet.
		# 2 - Node is up. Connections are pooled.
		# 3 - Node is down.
		if [[ "$NODE_STATE" == "3" ]]; then
			/usr/sbin/pcp_recovery_node 30 127.0.0.1 9898 $DB_USER $DB_PASSWORD $node;
		fi
	done
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
		# CH: WHY IS THE setup_pgpool NOT EXECUTED HERE? 
		# HOW ARE NEW PostgreSQL NODES ADDED TO PGPOOL?
		# service pgpool2 stop
		# setup_pgpool
		# service pgpool2 start
		
		service pgpool2 reload
		
		#Load data if none exists
		export -f import_data
		su postgres -c -m 'import_data'
		#Do online recovery for any new nodes
		export -f online_recovery
		su postgres -c -m 'online_recovery'
                ;;
esac

echo "[$(timestamp)] ---- Completed ----"

exit 0
