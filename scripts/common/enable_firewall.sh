#!/bin/bash
LOGFILE=/tmp/disable_firewall.log
exec  > $LOGFILE 2>&1

if [ "$1" != "" ]; then
  FW_ENABLED = "$1"
else
  FW_ENABLED = "false"
fi

if grep -q -i ubuntu /etc/*release
  then
    OSLEVEL=ubuntu
  else
    OSLEVEL=other
fi

if [ "$FW_ENABLED" == "false" ]; then
  if [ "$OSLEVEL" == "ubuntu" ]; then
    sudo service iptables stop
    sudo ufw disable
  else
    sudo systemctl disable firewalld
    sudo systemctl stop firewalld
  fi
else
  if [ "$OSLEVEL" == "ubuntu" ]; then
    sudo service iptables start
    sudo ufw enable
  else
    sudo systemctl enable firewalld
    sudo systemctl start firewalld
  fi
fi