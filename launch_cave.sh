#!/bin/bash

if [ $# == 0 ]
then
  echo "Start with $0 [FULL_PATH_TO_APPLICATION] [UNREAL_VERSION] [OPTIONAL ARGS]"
  exit
fi

application_filepath=$1
config_path="./config/cave_"$2".cfg"
additonal_args=${@:3}
worker_logs_folder=$(dirname ${application_filepath})"/worker_logs"
dtrack_ip="127.0.0.1"
dtrack_port="50105"

echo "Creating worker_logs directory if not existent."
mkdir -p $worker_logs_folder

echo -n "Starting DTrack: "
echo -e 'dtrack2 tracking start\0' | ncat $dtrack_ip $dtrack_port
echo

echo "Launching VRPN."
./vrpn/server_src/vrpn_server -f "./config/vrpn/vrpn.cfg" -millisleep 3 &
disown

cat ${config_path} | while read line
do
  #not the config part we are searching for
  if [[ "${line}" != "[cluster_node]"* ]] || [[ "${line}" == *"master"* ]] ; then
    continue
  fi
  
  #extract data
  name=$(echo "${line}" | awk '{split($0,a," "); split(a[2],b,"="); print b[2]}')
  ip=$(echo "${line}" | awk '{split($0,a," "); split(a[3],b,"="); print b[2]}')
  
  if [[ "${name}" == *"left_eye"* ]] ; then 
    display=":0.1"
  else
    display=":0.0"
  fi
  
  #launching worker
  echo "Launching worker ${name} with IP: ${ip}"
  ssh ${ip} "export DISPLAY=${display}; ${application_filepath} ResX=1920 ResY=1200 WinX=0 WinY=0 -nocore -fixedseed -nosplash -noverifygc -notexturestreaming -opengl4 -fullscreen dc_cfg=${config_path} dc_node=${name} -dc_cluster -dc_dev_mono ${additonal_args} &> ${worker_logs_folder}/${name}.log &" &

done

#wait for clients to be started
wait

echo "Launching master node."

${application_filepath} ResX=1600 ResY=1000 WinX=0 WinY=0 -nocore -fixedseed -nosplash -noverifygc -notexturestreaming -opengl4 -useallavailablecores -windowed dc_cfg=${config_path} dc_node=node_main -dc_cluster -dc_dev_mono ${additonal_args} 2>&1 | tee ${worker_logs_folder}/master.log &
wait $(pgrep -fn $(basename ${application_filepath}))

echo "Killing VRPN."
pkill -f vrpn

echo -n "Stopping DTrack: "
echo -e 'dtrack2 tracking stop\0' | ncat -i 500ms $dtrack_ip $dtrack_port
echo
