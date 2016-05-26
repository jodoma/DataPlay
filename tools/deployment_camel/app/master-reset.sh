#!/bin/bash
source /etc/profile.d/dataplay.sh
killall /home/ubuntu/www/dataplay/bin/dataplay
ulimit -n 500000
nohup /home/ubuntu/www/dataplay/bin/dataplay &
