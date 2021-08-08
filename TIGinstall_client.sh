### Run this script through srun

#!/bin/bash

OPT_GPU_MONITORING=true    # or set as false
INFLUXDB_USER="admin"
INFLUXDB_PWD="passw0rd"
TIG_SHARED=/shared/tig_scratch

INFLUXDB_SERVER=$(cat $TIG_SHARED/tig_server.conf)
if [ -z "$INFLUXDB_SERVER" ]; then
    echo "TIG server information could not be found. Make sure the ${TIG_SHARED}/tig_server.conf is accessible."
    exit 1
fi

os=$(awk -F= '/^NAME/{print $2}' /etc/os-release)
if [[ $os = *CentOS* ]]
then 
  echo "You are running on CentOS"
  echo "#### Telegraf Installation:"
  wget https://dl.influxdata.com/telegraf/releases/telegraf-1.19.1-1.x86_64.rpm
  yum localinstall -y telegraf-1.19.1-1.x86_64.rpm

elif [[ $os = *Ubuntu* ]]
then
  echo "You are running on Ubuntu"
  echo "### Telegraf Install:"
  wget https://dl.influxdata.com/telegraf/releases/telegraf_1.19.1-1_amd64.deb
  dpkg -i telegraf_1.19.1-1_amd64.deb
else
  echo "You are running on non-support OS" 
  exit 1]
fi  

echo "Push telegraph.conf .... "
mv /etc/telegraf/telegraf.conf /etc/telegraf/telegraf.conf.origin
cat <<EOF | sudo tee /etc/telegraf/telegraf.conf
[global_tags]
[agent]
  interval = "10s"
  round_interval = true
  metric_batch_size = 1000
  metric_buffer_limit = 10000
  collection_jitter = "0s"
  flush_interval = "10s"
  flush_jitter = "0s"
  precision = ""
  hostname = ""
  omit_hostname = false
[[inputs.cpu]]
  percpu = true
  totalcpu = true
  collect_cpu_time = false
  report_active = false
[[inputs.disk]]
  ignore_fs = ["tmpfs", "devtmpfs", "devfs", "iso9660", "overlay", "aufs", "squashfs"]
[[inputs.diskio]]
[[inputs.mem]]
[[inputs.processes]]
[[inputs.net]]
EOF

if ["$OPT_GPU_MONITORING"=true]
then
  echo "Config GPU monitoring .... "
  cat << EOF >> /etc/telegraf/telegraf.conf
[[inputs.nvidia_smi]]
  bin_path = "/usr/bin/nvidia-smi"
  # timeout = "5s"
EOF
fi

cat << EOF >> /etc/telegraf/telegraf.conf
[[outputs.influxdb]]
  urls = ["http://$INFLUXDB_SERVER:8086"]
  database = "monitor"
  username = "$INFLUXDB_USER"
  password = "$INFLUXDB_PWD"
EOF

echo "#### Starting Telegraf services:"
service telegraf stop
service telegraf start

echo "### Finished Telegraf setup"