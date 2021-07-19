### To add monitoring of CycleCloud cluster, here is a direct method operating on the scheduler VM.
### This method run the installation directly on existing Scheduler and ComoputeNodes VM.
### Reference link to method of prebuilding in cluster setup: https://github.com/andygeorgi/aztig

#!/bin/bash

cd ~
INFLUXDB_USER="admin"
INFLUXDB_PWD="passw0rd"
TIG_SHARED=/shared/tig_scratch
os=$(awk -F= '/^NAME/{print $2}' /etc/os-release)

if [[ $os = *CentOS* ]]
then 

  echo "### You are running on CentOS"
  echo "### InfluxDB installation"
  wget https://dl.influxdata.com/influxdb/releases/influxdb-1.8.6.x86_64.rpm
  yum localinstall -y influxdb-1.8.6.x86_64.rpm

  echo "### Grafana installation"
  wget https://dl.grafana.com/oss/release/grafana-8.0.6-1.x86_64.rpm
  yum localinstall -y grafana-8.0.6-1.x86_64.rpm
  
elif [[ $os = *Ubuntu* ]]
then 
  echo "### You are running on Ubuntu"
  echo "### InfluxDB installation"
  wget https://dl.influxdata.com/influxdb/releases/influxdb_1.8.6_amd64.deb
  dpkg -i influxdb_1.8.6_amd64.deb

  echo "### Grafana installation"
  apt-get install -y adduser libfontconfig1
  wget https://dl.grafana.com/oss/release/grafana_8.0.6_amd64.deb
  dpkg -i grafana_8.0.6_amd64.deb
  
else
  echo "You are running on non-support OS" 
  exit 1
fi

echo "#### Starting InfluxDB services"
service influxdb start

echo "#### Starting Grafana services"
systemctl daemon-reload
systemctl start grafana-server
systemctl enable grafana-server

#echo "#### Opening InfluxDB firewalld port 80(83|86):"
#sudo firewall-cmd --permanent --zone=public --add-port=8086/tcp
#sudo firewall-cmd --permanent --zone=public --add-port=8083/tcp
#echo "#### Opening Grafana firewalld port 3000:"
#sudo firewall-cmd --permanent --zone=public --add-port=3000/tcp
#echo "#### Reload firewall rules:"
#sudo firewall-cmd --reload

echo "#### Configuration of InfluxDB"
curl "http://localhost:8086/query" --data-urlencode "q=CREATE USER admindb WITH PASSWORD '$INFLUXDB_PWD' WITH ALL PRIVILEGES"
curl "http://localhost:8086/query" --data-urlencode "q=CREATE USER $INFLUXDB_USER WITH PASSWORD '$INFLUXDB_PWD'"
curl "http://localhost:8086/query" --data-urlencode "q=CREATE DATABASE monitor"
curl "http://localhost:8086/query" --data-urlencode "q=GRANT ALL ON monitor to $INFLUXDB_USER"

echo "### Config Grafana datasources"
cat <<EOF | sudo tee /etc/grafana/provisioning/datasources/aztig.yml
apiVersion: 1
datasources:
  - name: aztig
    type: influxdb
    access: proxy
    database: monitor
    user: $INFLUXDB_USER
    password: "$INFLUXDB_PWD"
    url: http://localhost:8086
    jsonData:
      httpMode: GET
EOF
chown grafana:grafana /etc/grafana/provisioning/datasources/*

echo "### Restart Grafana Server"
systemctl stop grafana-server
systemctl start grafana-server

echo "### Write Grafana server IP to a shared directory (to be read from clients)"
mkdir -p $TIG_SHARED
hostname -i > $TIG_SHARED/tig_server.conf

echo "### Finished Grafana & InfluxDB server setup"
