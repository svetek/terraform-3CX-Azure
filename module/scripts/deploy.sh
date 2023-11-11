#!/bin/bash

while getopts p: flag
do
    case "${flag}" in
        p) superset_password=${OPTARG};;
    esac
done
echo "Superset password: $superset_password";

# Install NFS modules
echo "# Debian Buster
      deb http://deb.debian.org/debian/ buster main
      deb-src http://deb.debian.org/debian/ buster main

      # Debian Buster
      deb http://deb.debian.org/debian-security/ buster/updates main
      deb-src http://deb.debian.org/debian-security/ buster/updates main

      # Debian Buster
      deb http://deb.debian.org/debian/ buster-updates main
      deb-src http://deb.debian.org/debian/ buster-updates main" > /etc/apt/sources.list.d/debian.list

apt update
apt -y install nfs-kernel-server
apt -y install nfs-common

# Install 3CX
apt -y remove nginx

wget -O- http://downloads-global.3cx.com/downloads/3cxpbx/public.key | sudo apt-key add -
apt install gnupg2 debconf-utils -y

apt-key adv --keyserver keyserver.ubuntu.com --recv-keys D34B9BFD90503A6B
echo "deb http://downloads-global.3cx.com/downloads/debian buster main" | tee /etc/apt/sources.list.d/3cxpbx.list
apt update
apt install -y net-tools dphys-swapfile
DEBIAN_FRONTEND=noninteractive apt -q -y --force-yes install 3cxpbx
#apt-get install -qq -y --no-install-recommends 3cxpbx

# Install superset
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo   "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update
apt-get -y install docker-ce docker-ce-cli containerd.io
curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /bin/docker-compose
chmod +x /bin/docker-compose
mkdir /opt/superset
mkdir /opt/superset/conf
chmod a+rwx /opt/superset/conf

#create user superset with encrypted password 'JHyuIJIYUtftyg887';
#grant all privileges on database database_single to superset;
#GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO superset;

cd /opt/superset && wget -c https://raw.githubusercontent.com/svetek/terraform-3CX-Azure/main/module/scripts/superset_docker-compose.yml  >> /tmp/install_log
mv /opt/superset/superset_docker-compose.yml /opt/superset/docker-compose.yml  >> /tmp/install_log
docker-compose up -d  >> /tmp/install_log &> /dev/null
sleep 30s
docker exec -i superset_app superset fab create-admin --username admin --firstname Superset --lastname Admin --email admin@superset.com --password $superset_password >> /tmp/install_log
docker exec -i superset_app superset db upgrade  >> /tmp/install_log
docker exec -i superset_app superset init  >> /tmp/install_log