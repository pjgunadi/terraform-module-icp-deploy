#!/bin/bash

cd /tmp/
wget https://github.com/heketi/heketi/releases/download/v5.0.1/heketi-v5.0.1.linux.amd64.tar.gz
tar -zxvf heketi-v5.0.1.linux.amd64.tar.gz
# wget https://github.com/heketi/heketi/releases/download/v6.0.0/heketi-v6.0.0.linux.amd64.tar.gz
# tar -zxvf heketi-v6.0.0.linux.amd64.tar.gz
mkdir /etc/heketi
mkdir /var/lib/heketi
cp heketi/heketi.json /etc/heketi/
cp heketi/heketi /usr/bin/
cp heketi/heketi-cli /usr/bin/

sed -i "s/\"executor\": \"mock\"/\"executor\": \"ssh\"/" /etc/heketi/heketi.json
sed -i "s/\"keyfile\": \".*\"/\"keyfile\": \"\/etc\/heketi\/heketi_key\"/" /etc/heketi/heketi.json
sed -i "s/\"user\": \"sshuser\"/\"user\": \"root\"/" /etc/heketi/heketi.json
sed -i "s/\"port\": \".*22\"/\"port\": \"22\"/" /etc/heketi/heketi.json
sed -i "s/\"fstab\": \".*\"/\"fstab\": \"\/etc\/fstab\"/" /etc/heketi/heketi.json
if [ "$1" != "" ]; then
  sed -i "s/\"use_auth\": .*/\"use_auth\": true,/" /etc/heketi/heketi.json
  sed -i "s/\"key\": \".*\"/\"key\": \"$1\"/" /etc/heketi/heketi.json
fi

cat <<EOF | tee -a /etc/heketi/heketi.service
[Unit]
Description=Heketi Server

[Service]
Type=simple
WorkingDirectory=/var/lib/heketi
EnvironmentFile=-/etc/heketi/heketi.env
User=root
ExecStart=/usr/bin/heketi --config=/etc/heketi/heketi.json
Restart=on-failure
StandardOutput=syslog
StandardError=syslog

[Install]
WantedBy=multi-user.target
EOF

ln -s /etc/heketi/heketi.service /etc/systemd/system
systemctl start heketi
