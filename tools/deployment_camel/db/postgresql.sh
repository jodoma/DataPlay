#!/bin/bash

# This is setup script for PostreSQL Database server.

set -ex

if [ "$(id -u)" != "0" ]; then
	echo >&2 "Error: This script must be run as user 'root'";
	exit 1
fi

source $(dirname $0)/../helper.sh
source $(dirname $0)/auth.inc.sh

timestamp () {
	date +"%F %T,%3N"
}

setuphost () {
	HOSTNAME=$(hostname)
	HOSTLOCAL="127.0.1.1"
	echo "$HOSTLOCAL $HOSTNAME" >> /etc/hosts
}

install_postgres () {
	# create ramdisk for postgres
	mkdir /var/lib/postgresql
	mount -t tmpfs -o size=2G none /var/lib/postgresql

	# install packages
	apt-get update
	apt-get install -y axel postgresql postgresql-9.4-pgpool2  sysstat htop dstat
	apt-get autoclean
	service postgresql restart
}

setup_database () {
	set -ex

	# Create a PostgreSQL user named 'playgen' with 'aDam3ntiUm' as the password and
	psql --command "CREATE USER $DB_USER WITH SUPERUSER PASSWORD '$DB_PASSWORD';"
	#createdb -O $DB_USER $DB_NAME
	echo "$DB_HOST:*:*:$DB_USER:$DB_PASSWORD" >> ~/.pgpass
	chmod 0600 /var/lib/postgresql/.pgpass
	
	psql --command "CREATE EXTENSION pgpool_recovery;" template1

	# Adjust PostgreSQL configuration so that remote connections to the database are possible.
	# From private network and omistack public network
	rm /etc/postgresql/$DB_VERSION/main/pg_hba.conf
	echo "
	local   all             all                                     peer
	host    all             all             127.0.0.1/32            md5
	host    all             all             ::1/128                 md5
	host    all             all             192.168.0.0/16        md5
	host    all             all             134.60.0.0/16        md5
	host    all             all             109.231.0.0/16        md5
	" >> /etc/postgresql/$DB_VERSION/main/pg_hba.conf
	
	# add IP and Port to listen on
	verify_variable_set "PUBLIC_PSQLINCOMING"
	ip="0.0.0.0"
	port=${PUBLIC_PSQLINCOMING}
	echo "listen_addresses='${ip}'" >> /etc/postgresql/$DB_VERSION/main/postgresql.conf
	perl -pi -e 's/^port.*$//' /etc/postgresql/$DB_VERSION/main/postgresql.conf
	echo "port=${port}" >> /etc/postgresql/$DB_VERSION/main/postgresql.conf
	#sed -i -e 's/max_connections = 100/max_connections = 154/g' /etc/postgresql/$DB_VERSION/main/postgresql.conf
}

setup_pgpool_scripts() {
	cp $(dirname $0)/{pgpool_recovery,pgpool_remote_start} /var/lib/postgresql/$DB_VERSION/main/
	chown postgres:postgres /var/lib/postgresql/$DB_VERSION/main/{pgpool_recovery,pgpool_remote_start}
	chmod +x /var/lib/postgresql/$DB_VERSION/main/{pgpool_recovery,pgpool_remote_start}
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
		export -f setup_database
                export -f verify_variable_set
                export -f log		
		su postgres -c -m 'setup_database'
		#sudo -u postgres $(typeset -f setup_database); setup_database # Run function as user 'postgres'
		echo "[$(timestamp)] ---- 5. Setup pgpool scripts ----"
		setup_pgpool_scripts
		echo "[$(timestamp)] ---- 6. Restart PostgreSQL as root ----"
		service postgresql restart
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
