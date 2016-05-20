#!/bin/bash

# This is setup script for Cassandra Single-Node server.

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

LOGFILENAME=cassandra.log
LOGFILE=$LOGDIR/$LOGFILENAME

logsetup

check_variables () {
	verify_variable_set "CONTAINER_IP"
	verify_variable_set "CassandraInport"
	verify_variable_notempty "CONTAINER_IP"
	verify_variable_notempty "CassandraInport"
	
	## probably setting this to CLOUD_IP is wiser?
	IP=$CONTAINER_IP	
}

export JAVA_HOME=/usr/lib/jvm/java-8-oracle
export CASSANDRA_CONFIG=/etc/cassandra


CASSANDRA_DIR="/var/lib/cassandra"
DATA_DIR="$CASSANDRA_DIR/data"
LOG_DIR="$CASSANDRA_DIR/commitlog"
SOURCE_DIR="/tmp/cassandra-data"
KEYSPACE="dataplay"

#IP=`ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}'`
### we will have to update this if we run inside a container.
MAX_RETRIES="500"
TIMEOUT="10"

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

install_java () {

	### FIXME: install Java 8
	echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | debconf-set-selections
	apt-add-repository -y ppa:webupd8team/java
	apt-get update
	apt-get install -y --allow-unauthenticated  axel oracle-java8-installer
	. /etc/profile
}

check_cassandra() {
	TRY="1"
	if [[ $TRY -ge $MAX_RETRIES ]]; then
		echo >&2 "Error: Unable Connect to Cassandra."; exit 1;
	fi
	until [[ $TRY -lt $MAX_RETRIES ]] && cqlsh $IP -e "exit" ; do
		echo "Connect: attempt $TRY failed! trying again in $TIMEOUT seconds..."
		TRY=$[$TRY+1]
		sleep $TIMEOUT
	done
}

restart_cassandra() {
	service cassandra restart
	echo "Waiting for Cassandra restart..."
	check_cassandra
	echo "Cassandra is UP!"
}

install_cassandra () {
	echo "deb http://debian.datastax.com/community stable main" | sudo tee -a /etc/apt/sources.list.d/cassandra.sources.list && \
	curl -L http://debian.datastax.com/debian/repo_key | sudo apt-key add - && \
	apt-get update && \
	apt-get install -y --allow-unauthenticated cassandra sysstat htop

	 sed -i -e 's/ulimit/#ulimit/g' /etc/init.d/cassandra
	echo "export CASSANDRA_CONFIG=/etc/cassandra" >> /etc/profile.d/dataplay.sh
	service cassandra stop
	update-rc.d cassandra disable

	# . /etc/profile
	mkdir -p $DATA_DIR/$KEYSPACE/
	chown -R cassandra:cassandra $CASSANDRA_DIR/ # Fix permissions
	
}

configure_cassandra () {
	# sed -i -e "s/num_tokens/\#num_tokens/" /etc/cassandra/cassandra.yaml # Disable virtual nodes
	sed -i -e "s/^listen_address.*/listen_address: $IP/" /etc/cassandra/cassandra.yaml # Listen on IP of the container
	sed -i -e "s/^rpc_address.*/rpc_address: $IP/" /etc/cassandra/cassandra.yaml # Enable Remote connections
	# sed -i -e "s/^broadcast_rpc_address.*/broadcast_rpc_address: $IP/" /etc/cassandra/cassandra.yaml # Enable Remote connections
	sed -i -e "s/- seeds: \"127.0.0.1\"/- seeds: \"$IP\"/" /etc/cassandra/cassandra.yaml # Be your own seed

	# With virtual nodes disabled, we need to manually specify the token
	# sed -i -e "s/# JVM_OPTS=\"$JVM_OPTS -Djava.rmi.server.hostname=<public name>\"/ JVM_OPTS=\"$JVM_OPTS -Djava.rmi.server.hostname=$IP\"/" /etc/cassandra/cassandra-env.sh
	# echo "JVM_OPTS=\"\$JVM_OPTS -Dcassandra.initial_token=0\"" >> /etc/cassandra/cassandra-env.sh

	# netstat -an | grep 9160.*LISTEN

	restart_cassandra
}

install_opscenter () {
	apt-get install -y opscenter && \
	service opscenterd start

	# Connect using http://<IP>:8888
}

export_variables () {
	. /etc/profile

	su - ubuntu -c ". /etc/profile"
}

import_data () {
	LASTDATE=$(date +%Y-%m-%d) # Today
	BACKUP_HOST="109.231.121.72" # Flexiant C2
	#BACKUP_HOST="108.61.197.87" # Vultr
	BACKUP_PORT="8080"
	BACKUP_DIR="cassandra/$LASTDATE"
	BACKUP_USER="playgen"
	BACKUP_PASS="D%40taP1aY"

	BACKUP_SCHEMA_FILE="$KEYSPACE-schema.cql"
	BACKUP_DATA_FILE="$KEYSPACE-data.tar.gz"

	i="1"
	until [[ $i -lt $MAX_RETRIES ]] && axel -a "http://$BACKUP_USER:$BACKUP_PASS@$BACKUP_HOST:$BACKUP_PORT/$BACKUP_DIR/$BACKUP_SCHEMA_FILE"; do
		LASTDATE=$(date +%Y-%m-%d --date="$LASTDATE -1 days") # Decrement by 1 Day
		BACKUP_DIR="cassandra/$LASTDATE"
		echo "Latest $BACKUP_SCHEMA_FILE backup not available, trying $LASTDATE"
		i=$[$i+1]
		if [[ $i -ge $MAX_RETRIES ]]; then
			echo >&2 "Error: Unable to fetch '$BACKUP_SCHEMA_FILE' from backup server."; exit 1;
		fi
	done

	j="1"
	until [[ $j -lt $MAX_RETRIES ]] && axel -a "http://$BACKUP_USER:$BACKUP_PASS@$BACKUP_HOST:$BACKUP_PORT/$BACKUP_DIR/$BACKUP_DATA_FILE"; do
		LASTDATE=$(date +%Y-%m-%d --date="$LASTDATE -1 days") # Decrement by 1 Day
		BACKUP_DIR="cassandra/$LASTDATE"
		echo "Latest $BACKUP_DATA_FILE backup not available, trying $LASTDATE"
		j=$[$j+1]
		if [[ $j -ge $MAX_RETRIES ]]; then
			echo >&2 "Error: Unable to fetch '$BACKUP_DATA_FILE' from backup server."; exit 1;
		fi
	done

	restart_cassandra
	check_cassandra
	##FIXME: verify sedexpression
	#SEARCH="AND caching = {\"keys\":\"ALL\", \"rows_per_partition\":\"NONE\"}"
	#REPLACE="AND caching = {'keys':'ALL', 'rows_per_partition':'NONE'}'"
	#sed -i -e "s/$SEARCH/$REPLACE/g" $BACKUP_SCHEMA_FILE
	sed -i -e "s/AND caching = '{\"keys\":\"ALL\", \"rows_per_partition\":\"NONE\"}'/AND caching = { 'keys':'ALL', 'rows_per_partition' : 'NONE'}/g" $BACKUP_SCHEMA_FILE
       #cqlsh $IP -f $(dirname  $BACKUP_SCHEMA_FILE)/dataplay-schema.cql.bkp
       cqlsh $IP -f $BACKUP_SCHEMA_FILE


	service cassandra stop

	mkdir -p $SOURCE_DIR
	tar -xzvf $BACKUP_DATA_FILE -C $SOURCE_DIR
	SOURCE_TABLES=`ls -l $SOURCE_DIR | egrep '^d' | awk '{print $9}'`
	for table in $SOURCE_TABLES; do
		table_name=$(echo $table | awk -F'-' '{print $1}')
		mv $SOURCE_DIR/$table/* $DATA_DIR/$KEYSPACE/$table_name-*
	done

	chown -R cassandra:cassandra $DATA_DIR # Fix permissions
	chown -R cassandra:cassandra $CASSANDRA_DIR # Fix permissions

	rm -rf $LOG_DIR/*.log

	# restart_cassandra

	# nodetool -h $IP repair $KEYSPACE

	rm -rf $SOURCE_DIR
}

#update_iptables () {
#	# iptables -A INPUT -p tcp --dport 7000 -j ACCEPT # Internode communication (not used if TLS enabled) Used internal by Cassandra
#	iptables -A INPUT -p tcp --dport 7199 -j ACCEPT # JMX
#	iptables -A INPUT -p tcp --dport 8888 -j ACCEPT # OpsCenter
#	iptables -A INPUT -p tcp --dport 9042 -j ACCEPT # CQL
#	iptables -A INPUT -p tcp --dport 9160 -j ACCEPT # Thift client API
#
#	iptables-save
#}

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

case "$1" in
        install)
		echo "[$(timestamp)] ---- 1. Setup Host ----"
		setuphost
		echo "[$(timestamp)] ---- 2. Install Oracle Java 7 ----"
		install_java
		echo "[$(timestamp)] ---- 3. Install Cassandra ----"
		install_cassandra
		;;
	configure)
		check_variables
		echo "[$(timestamp)] ---- 4. Configure Cassandra ----"
		configure_cassandra
		#echo "[$(timestamp)] ---- 5. Export Variables ----"
		#export_variables
		echo "[$(timestamp)] ---- 6. Import Data ----"
		import_data
		#echo "[$(timestamp)] ---- 7. Update IPTables rules ----"
		#update_iptables
		#echo "[$(timestamp)] ---- 8. Setting up JCatascopia Agent ----"
		#setup_JCatascopiaAgent
		;;
	start)
		check_variables
		restart_cassandra
		#exec sleep infinity
		#sleep infinity
		;;
	stop)
		service cassandra stop
		kill 1
		;;
esac

echo "[$(timestamp)] ---- Completed ----"

exit 0
