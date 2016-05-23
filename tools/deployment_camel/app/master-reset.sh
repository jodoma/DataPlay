#!/bin/bash
source /etc/profile.d/dataplay.sh
killall /home/ubuntu/www/dataplay/bin/dataplay
nohup /home/ubuntu/www/dataplay/bin/dataplay &