#!/usr/bin/env bash
# TODO: Add precision in time (milliseconds, bytes)

# Debug
#set -x

# Config
curl_max=15
ten_MB_file="http://speedtest.wdc01.softlayer.com/downloads/test10.zip"
tor_min_speed=500
tor_host=$1
tor_socks_port=$2
tor_control_port=$3
tor_pid=$4

# Start loop for trying find best proxy
count=0
#while [ $time -ge ${curl_max} ]; do
while true; do
  let "count++"

  # Add some logs to terminal
  echo -n "Tor ${tor_host}:${tor_socks_port} checking speed attemp ${count}: "

  # Restart tor if to many attempts
  if [[ ${count} > 3 ]]; then
    echo -n "restarting tor... "
    kill -HUP ${tor_pid}
    echo -n "done, "
  fi

  # Stop trying if tor is bad
  if [[ ${count} > 5 ]]; then
    break
    # TODO: Deal with bad tor
  fi

  # Get download start time
  start=$(date +%s)

  # Download file and store finish time
  curl --silent --connect-timeout ${curl_max} --max-time ${curl_max} \
    --socks5-hostname ${tor_host}:${tor_socks_port} ${ten_MB_file} --output /dev/null
  end=$(date +%s)

  # Calculate spent seconds and speed
  time=$(expr ${end} - ${start})
  speed=0
  if [ ${time} -ne 0 ]; then
    speed=$(expr 10000 / ${time})
  fi
  echo -n "speed is ${speed} KB/s, "

  # Stop execution if speed is ok
  if [ ${speed} -ge ${tor_min_speed} ]; then
    echo "done."
    exit 0
  fi

  # In other case say tor to recreate circuits
  echo -n "tor recreating circuits... "
  #{ echo "authenticate """; echo "signal newnym"; } | telnet ${tor_host} ${tor_control_port} > /dev/null
  { echo "authenticate """; echo "signal newnym"; } | nc -q1 ${tor_host} ${tor_control_port} > /dev/null
  echo "done."
done

