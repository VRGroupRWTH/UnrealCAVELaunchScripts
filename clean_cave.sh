#!/bin/bash

echo "Starting to kill worker node applications."

# this extracts all ip addresses from some config, sorts them and removes duplicates. Then it loops over all IPs
cat "./config/cave_422.cfg" | grep -oP "^\[cluster_node\].*addr=\K[0-9\.]*" | sort -Vu | while read line
do 
 # extract data
 ip=${line}
  
 # killing worker
 echo "Killing application on worker with IP: ${ip}"
 ssh ${ip} 'pkill -KILL -f "dc_cluster|CrashReportClient"' &
done

# wait for clients to be killed
wait

echo "Killing VRPN."
pkill -9 -f vrpn

echo -n "Stopping DTrack (fails if already stopped): "
echo -e 'dtrack2 tracking stop\0' | ncat -i 500ms $dtrack_ip $dtrack_port
echo
