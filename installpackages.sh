#!/bin/bash

until [[ $SERVER_ID =~ [[:digit:]]{4} ]]; do
read -rp "Enter the Server ID: " SERVER_ID
done

until [[ $PLANT_NAME =~ ^[0-9a-zA-Z]+$ ]] || [[ $PLANT_NAME == *['!'@#\$%^\&*()_+]* ]]; do
read -rp "Enter the Plant Name: " PLANT_NAME
done

until [[ $MYSQL_PASS =~ ^[0-9a-zA-Z]+$ ]] || [[ $MYSQL_PASS == *['!'@#\$%^\&*()_+]* ]]; do
read -rp "Enter the Mysql Pass: " MYSQL_PASS
done

until [[ $ETHERNET_DEV =~ ^[0-9a-zA-Z]+$ ]]; do
read -rp "Enter the Ethernet Device Name: " ETHERNET_DEV
done

until [[ $HostName =~ ^[0-9a-zA-Z]+$ ]]; do
read -rp "Enter the Device HostName: " HostName
done

echo "*************************************** Server Configured Settings ***************************************"
echo "Server ID: " $SERVER_ID
echo "Plant Name: " $PLANT_NAME
echo "Server MYSQL PASS: " $MYSQL_PASS
echo "Ethernet Driver Name: " $ETHERNET_DEV
echo "Server HostName: " $HostName
echo "**********************************************************************************************************"

read -rp "Do you really want to continue with this settings? [y/n]: " REMOVE
if [[ $REMOVE == 'y' ]] || [[ $REMOVE == 'Y' ]]; then
echo "Server BSP installation started....."
else
echo "Server BSP installation Aborted....."
exit 0;
fi

SCRIPT_DIR=$(pwd)
IPLON_PACKAGE_PATH="/opt/iplon"

NTP_IP="192.168."$(echo $SERVER_ID | cut -c1-2).81
SERVER_IP="192.168."$(echo $SERVER_ID | cut -c1-2).$(echo $SERVER_ID | cut -c3-4)
FIREWALL_IP="192.168."$(echo $SERVER_ID | cut -c1-2).100
$(rm /etc/netplan/*yaml)
NetPlan_File="/etc/netplan/00-installer-config.yaml"
$(touch $NetPlan_File)

# Upd ate Repository
apt update

################################################## NETPLAN CONFIGURATION ##################################################

echo "# This is the network config written by subiquity
network:
ethernets:
    $ETHERNET_DEV:
     addresses:
         - $SERVER_IP/24
     nameservers:
         addresses:
            - 8.8.8.8
            - 8.8.4.4
     dhcp4: false
     routes:
        - to: default
         via: $FIREWALL_IP
version: 2" >>$NetPlan_File

################################################# HostName CONFIGURATION ##################################################

sed -i "s/iplon/$HostName/g" /etc/hosts
sed -i "s/iplon/$HostName/g" /etc/hostname

################################################# FUNCTION FOR PACKAGE INSTALLATION ##################################################

installPackage() {
for PACKAGE in "$@"; do
    if [ $(dpkg-query -W -f='${Status}' $PACKAGE 2>/dev/null | grep -c "install ok") -eq 0 ]; then
     echo "Installing $PACKAGE !"
     apt install -qq -y $PACKAGE;
    else
     echo "$PACKAGE already installed !"
    fi
done
}

################################################# FUNCTION FOR DOCKER VOLUME CREATION ##################################################

dockerVolume() {
for PACKAGE in "$@"; do
     docker volume create --name=$PACKAGE;    
done
}

################################################# TOOLS INSTALLATION ##################################################

se t -x;
installPackage vim tcpdump screen unrar htop dos2unix expect ncdu sshpass net-tools nmap ntp curl wget gnupg samba vsftpd figlet lolcat

################################################# ROOT Privillages Updation ##################################################

USER="root"
GROUP="root"
passw=$(echo 'aVBMT05ASW9UNgo=' | base64 --decode)

groupadd $GROUP
useradd $USER -m -d /home/$USER -s /bin/bash -g $GROUP

exp()
{
    "$1" <(cat <<-EOF
    spawn passwd $USER
    expect "Enter new UNIX password:"
    send -- "$passw\r"
    expect "Retype new UNIX password:"
    send -- "$passw\r"
    expect eof
    EOF
    )
    echo "password for USER $USER updated successfully - adding to sudoers file now"
}


exp "/usr/bin/expect"

sed -i '12 a Defaults        rootpw' /etc/sudoers

################################################# NTP CONFIGURATION ##################################################

if [ $(cat /etc/ntp.conf | grep -c $NTP_IP) -eq 0 ]; then
sed -i '20 a server $NTP_IP' /etc/ntp.conf
fi
if [ $(cat /etc/ntp.conf | grep -c "server 0.in.pool.ntp.org") -eq 0 ]; then
sed -i '21 a server 0.in.pool.ntp.org' /etc/ntp.conf
fi

################################################# CONTAINER INSTALLATION START ##################################################

apt install apt-transport-https ca-certificates curl software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update
installPackage docker-ce docker-compose

################################################# Docker Images Loadded ##################################################

cd $SCRIPT_DIR

docker load -i grafana_v9.4.7.tar.gz
rm $SCRIPT_DIR/grafana_v9.4.7.tar.gz

docker load -i iec61850_v1.9.0.tar.gz
rm $SCRIPT_DIR/iec61850_v1.9.0.tar.gz

docker load -i influxdb_v2.4.0.tar.gz
rm $SCRIPT_DIR/influxdb_v2.4.0.tar.gz

docker load -i iplon-opcua_v2.0.tar.gz
rm $SCRIPT_DIR/iplon-opcua_v2.0.tar.gz

docker load -i loki_v2.8.0.tar.gz
rm $SCRIPT_DIR/loki_v2.8.0.tar.gz

docker load -i pgadmin_v4.tar.gz
rm $SCRIPT_DIR/pgadmin_v4.tar.gz

docker load -i postgresql_v12.tar.gz
rm $SCRIPT_DIR/postgresql_v12.tar.gz

docker load -i postsql_v12.tar.gz
rm $SCRIPT_DIR/postsql_v12.tar.gz

docker load -i prometheus_v2.43.0.tar.gz
rm $SCRIPT_DIR/prometheus_v2.43.0.tar.gz

docker load -i promtail_v2.8.0.tar.gz
rm $SCRIPT_DIR/promtail_v2.8.0.tar.gz

docker load -i pushgateway_v1.5.1.tar.gz
rm $SCRIPT_DIR/pushgateway_v1.5.1.tar.gz

docker load -i rabbitmq_v3.12.2.tar.gz
rm $SCRIPT_DIR/rabbitmq_v3.12.2.tar.gz

docker load -i scabackfast_v4.1.tar.gz
rm $SCRIPT_DIR/scabackfast_v4.1.tar.gz

docker load -i scaback_v4.1.tar.gz
rm $SCRIPT_DIR/scaback_v4.1.tar.gz

docker load -i scaback_vcollect.tar.gz
rm $SCRIPT_DIR/scaback_vcollect.tar.gz

docker load -i scabackFast_vcollect.tar.gz
rm $SCRIPT_DIR/scabackFast_vcollect.tar.gz

docker load -i telegraf_v1.24.2.tar.gz
rm $SCRIPT_DIR/telegraf_v1.24.2.tar.gz

docker load -i node-red_v3.0.2.tar.gz
rm $SCRIPT_DIR/node-red_v3.0.2.tar.gz

################################################# CONTAINER VOLUME CREATION ##################################################

dockerVolume scaback-lib scabackFast-lib influxdb-etc influxdb-lib influxdb-log postgresql-etc postgresql-lib postgresql-log postsql_grafana-etc postsql_grafana-lib postsql_grafana-log pgadmin-etc pgadmin-log grafana-etc grafana-lib grafana-log telegraf-etc telegraf-log nodered-lib nodered-log iplon-opcua-lib iplon-opcua-log rabbitmq-etc rabbitmq-log prometheus-lib loki-lib promtail-lib

################################################# CONTAINER CREATION ##################################################

cd $SCRIPT_DIR
docker-compose up -d

tar -xJf serverData.tar.xz -C /
rm $SCRIPT_DIR/serverData.tar.xz

apt update

service ssh restart
systemctl enable ssh
service ntp restart
service cron restart
sleep 15

################################################# UFW PORT BLOCKING ##################################################

ufw enable
ufw allow 21
ufw allow 22
ufw allow 53
ufw allow 80
ufw allow 502
ufw allow 8000
ufw allow 5000
ufw allow 5001
ufw allow 1880
ufw allow 3000
ufw allow 15672
ufw allow 1883

figlet -w 120 Package Installation Finished... | lolcat
figlet -w 120 wait for few minutes... | lolcat
figlet -w 120 System Rebooting... | lolcat
figlet -w 120 ALL THE BEST...! | lolcat

sleep 150;
rm $SCRIPT_DIR/installPackages.sh
netplan apply
sudo reboot
