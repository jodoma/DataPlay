#!/bin/bash

# This is setup script for PostreSQL Database server.

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

install_postgres () {
	apt-get update
	apt-get install -y axel postgresql postgresql-9.4-pgpool2
	apt-get autoclean
	service postgresql restart
}

setup_database () {
	source $(dirname $0)/../helper.sh

	DB_USER="playgen"
	DB_PASSWORD="aDam3ntiUm"
	DB_NAME="dataplay"
	DB_VERSION="9.4"

	# Create a PostgreSQL user named 'playgen' with 'aDam3ntiUm' as the password and
	# then create a database 'dataplay' owned by the 'playgen' role.
	psql --command "CREATE USER $DB_USER WITH SUPERUSER PASSWORD '$DB_PASSWORD';" && \
	createdb -O $DB_USER $DB_NAME

	# Adjust PostgreSQL configuration so that remote connections to the database are possible.
	# From private network and omistack public network
	echo "host    all             all             192.168.0.0/16        md5" >> /etc/postgresql/$DB_VERSION/main/pg_hba.conf
	echo "host    all             all             134.60.0.0/16        md5" >> /etc/postgresql/$DB_VERSION/main/pg_hba.conf
	
	# add IP and Port to listen on
	verify_variable_set "PUBLIC_PSQLINCOMING"
	ip="0.0.0.0"
	port=${PUBLIC_PSQLINCOMING}
	echo "listen_addresses='${ip}'" >> /etc/postgresql/$DB_VERSION/main/postgresql.conf
	echo "port=${port}" >> /etc/postgresql/$DB_VERSION/main/postgresql.conf
}

import_data () {
	MAX_RETRIES="200"

	DB_HOST="localhost"
	DB_PORT="5432"
	DB_USER="playgen"
	DB_PASSWORD="aDam3ntiUm"
	DB_NAME="dataplay"

	LASTDATE=$(date +%Y-%m-%d) # Today
	BACKUP_HOST="109.231.121.72"
	BACKUP_PORT="8080"
	BACKUP_DIR="postgresql/$LASTDATE-daily"
	BACKUP_USER="playgen"
	BACKUP_PASS="D%40taP1aY"
	BACKUP_FILE="$DB_NAME.sql.gz"

	echo "$DB_HOST:$DB_PORT:$DB_NAME:$DB_USER:$DB_PASSWORD" > .pgpass && chmod 0600 .pgpass

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
	psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f $DB_NAME.sql
}

setup_pgpool_access() {
	DB_VERSION="9.4"
	DB_HOST="localhost"
	DB_PORT="5432"
	DB_USER="playgen"
	DB_PASSWORD="aDam3ntiUm"
	DB_NAME="dataplay"
	PGPOOL_VERSION="3.3.4"

	#cp /var/lib/postgresql/.pgpass ~/.pgpass

	mkdir ~/pgpool-local

	wget http://www.pgpool.net/download.php?f=pgpool-II-$PGPOOL_VERSION.tar.gz -O pgpool-II-$PGPOOL_VERSION.tar.gz

	tar -xvzf pgpool-II-$PGPOOL_VERSION.tar.gz

	#cp pgpool-II-$PGPOOL_VERSION/src/sql/pgpool_adm/pgpool_adm.sql.in ~/pgpool-local/pgpool_adm.sql
	cp pgpool-II-$PGPOOL_VERSION/src/sql/pgpool-recovery/pgpool-recovery.sql.in ~/pgpool-local/pgpool-recovery.sql
	cp pgpool-II-$PGPOOL_VERSION/src/sql/pgpool-regclass/pgpool-regclass.sql.in ~/pgpool-local/pgpool-regclass.sql

	#sed -i "s/MODULE_PATHNAME/\/usr\/lib\/postgresql\/$DB_VERSION\/lib\/pgpool_adm/g" ~/pgpool-local/pgpool_adm.sql
	# Note: error on line # 45 & 51 should retrun integer
	#sed -i "43,51s/record/integer/" ~/pgpool-local/pgpool_adm.sql

	sed -i "s/MODULE_PATHNAME/\/usr\/lib\/postgresql\/$DB_VERSION\/lib\/pgpool-recovery/g" ~/pgpool-local/pgpool-recovery.sql
	sed -i "s/\$libdir\/pgpool-recovery/\/usr\/lib\/postgresql\/$DB_VERSION\/lib\/pgpool-recovery/g" ~/pgpool-local/pgpool-recovery.sql
	sed -i "s/MODULE_PATHNAME/\/usr\/lib\/postgresql\/$DB_VERSION\/lib\/pgpool-regclass/g" ~/pgpool-local/pgpool-regclass.sql

	#psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f ~/pgpool-local/pgpool_adm.sql
	psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f ~/pgpool-local/pgpool-recovery.sql
	psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f ~/pgpool-local/pgpool-regclass.sql

	service postgresql restart
}

case "$1" in
        install)
		echo "[$(timestamp)] ---- 1. Setup Host ----"
		setuphost
		echo "[$(timestamp)] ---- 2. Install PostgresSQL ----"
		install_postgres
		echo "[$(timestamp)] ---- 3. Setup Database ----"
		;;
	configure)
		echo "[$(timestamp)] ---- 4. Create user and database ----"
		sudo -u postgres "$(typeset -f setup_database); setup_database" # Run function as user 'postgres'
		echo "[$(timestamp)] ---- 5. Setup pgpool access ----"
		setup_pgpool_access	
		echo "[$(timestamp)] ---- 6. Restart PostgreSQL as root ----"
		service postgresql restart
		echo "[$(timestamp)] ---- 7. Import Data ----"
		sudo -u postgres "$(typeset -f import_data); import_data" # Run function as user 'postgres'
		;;
	start)
		service postgresql stop
		service postgresql start
		#sleep infinity
		;;
	stop)
		service postgresql stop
		;;
	startdetect)
                ;;
        stopdetect)
                ;;
        updateports)
		;;
esac

echo "[$(timestamp)] ---- Completed ----"

exit 0
