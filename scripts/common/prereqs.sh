#!/bin/bash
#This script updates hosts with required prereqs
#if [ $# -lt 1 ]; then
#  echo "Usage $0 <hostname>"
#  exit 1
#fi

#HOSTNAME=$1

LOGFILE=/tmp/prereqs.log
exec > $LOGFILE 2>&1

#Find Linux Distro
if grep -q -i ubuntu /etc/*release
  then
    OSLEVEL=ubuntu
  else
    OSLEVEL=other
fi
echo "Operating System is $OSLEVEL"

ubuntu_install(){
  echo "vm.max_map_count=262144" | sudo tee /etc/sysctl.d/90-icp.conf
  echo "net.ipv4.ip_local_port_range=10240 60999" | sudo tee -a /etc/sysctl.d/90-icp.conf
  sudo sysctl -p /etc/sysctl.d/90-icp.conf
  sudo apt-get -y update
  sudo apt-get install -y apt-transport-https nfs-common ca-certificates curl software-properties-common
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  ## Attempt to avoid probelems when dpkg requires configuration
  export DEBIAN_FRONTEND=noninteractive
  export DEBIAN_PRIORITY=critical
  sudo -E apt-get -y update
  sudo -E apt-get -yq -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" upgrade
  #sudo apt-get -y upgrade
  sudo apt-get install -y python python-pip socat unzip moreutils glusterfs-client
  sudo service iptables stop
  sudo ufw disable
  sudo apt-get install -y docker-ce
  sudo service docker start
  sudo pip install --upgrade pip
  sudo pip install pyyaml paramiko
  sudo modprobe dm_thin_pool
  [ -f /etc/modules ] && grep dm_thin_pool /etc/modules || echo dm_thin_pool | sudo tee -a /etc/modules
  #echo y | pip uninstall docker-py
}
crlinux_install(){
  #Disable SELINUX
  sudo sed -i s/^SELINUX=enforcing/SELINUX=disabled/ /etc/selinux/config && sudo setenforce 0
  sudo systemctl disable firewalld
  sudo systemctl stop firewalld
  echo "vm.max_map_count=262144" | sudo tee /etc/sysctl.d/90-icp.conf
  echo "net.ipv4.ip_local_port_range=10240 60999" | sudo tee -a /etc/sysctl.d/90-icp.conf
  sudo sysctl -p /etc/sysctl.d/90-icp.conf
  #install epel
  sudo yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
  sudo yum -y install python-setuptools policycoreutils-python socat unzip glusterfs-client
  sudo easy_install pip
  sudo pip install pyyaml paramiko
  sudo rpm -ivh http://mirror.centos.org/centos/7/extras/x86_64/Packages/container-selinux-2.21-1.el7.noarch.rpm
  #add docker repo and install
  sudo yum install -y yum-utils device-mapper-persistent-data lvm2
  sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  sudo yum -y install docker-ce
  sudo systemctl enable docker
  sudo systemctl start docker
  sudo modprobe dm_thin_pool
  [ -f /etc/modules-load.d/dm_thin_pool.conf ] && grep dm_thin_pool /etc/modules-load.d/dm_thin_pool.conf || echo dm_thin_pool | sudo tee -a /etc/modules-load.d/dm_thin_pool.conf
}

if [ "$OSLEVEL" == "ubuntu" ]; then
  ubuntu_install
else
  crlinux_install
fi

echo "Complete.."
exit 0
