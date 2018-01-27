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
  #Update the source resgitry
  #sudo sysctl -w vm.max_map_count=262144
  #Update hostname
#  sudo hostname $HOSTNAME
#  sudo echo $HOSTNAME > /etc/hostname
  echo "vm.max_map_count=262144" | sudo tee /etc/sysctl.d/90-icp.conf
  echo 'net.ipv4.ip_local_port_range="10240 60999"' | sudo tee -a /etc/sysctl.d/90-icp.conf
  sudo sysctl -p /etc/sysctl.d/90-icp.conf
  sudo apt-get -y update
  sudo apt-get install -y apt-transport-https nfs-common ca-certificates curl software-properties-common
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  sudo apt-get update -y
  sudo apt-get -y upgrade
  sudo apt-get install -y python python-pip socat #unzip moreutils 
  sudo service iptables stop
  sudo ufw disable
  sudo apt-get install -y docker-ce
  sudo service docker start
  pip install --upgrade pip
  #echo y | pip uninstall docker-py
}
crlinux_install(){
  #Update hostname
#  hostnamectl set-hostname $HOSTNAME
  #install epel
  #cd /tmp
  #wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
  #yum -y install local epel-release-latest-7.noarch.rpm
  sudo yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
  #yum clean all
  #yum repolist
  #Install net-tools
  #yum -y install net-tools
  #sysctl -w vm.max_map_count=262144
  echo "vm.max_map_count=262144" | sudo tee /etc/sysctl.d/90-icp.conf
  echo 'net.ipv4.ip_local_port_range="10240 60999"' | sudo tee -a /etc/sysctl.d/90-icp.conf
  sudo sysctl -p /etc/sysctl.d/90-icp.conf
  #Disable SELINUX
  sudo sed -i s/^SELINUX=enforcing/SELINUX=disabled/ /etc/selinux/config && setenforce 0
  sudo systemctl disable firewalld
  sudo systemctl stop firewalld
  #yum -y install unzip
  #yum -y install moreutils
  #yum -y install ntp
  #yum -y install python-pip
  sudo yum -y install python-setuptools policycoreutils-python socat
  sudo easy_install pip
  sudo rpm -ivh http://mirror.centos.org/centos/7/extras/x86_64/Packages/container-selinux-2.21-1.el7.noarch.rpm
  #add docker repo and install
  sudo yum install -y yum-utils device-mapper-persistent-data lvm2
  sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  #yum-config-manager --enable docker-ce-edge
  #yum-config-manager --enable docker-ce-testing
  #yum-config-manager --disable docker-ce-edge
  #yum -y makecache fast
  sudo yum -y install docker-ce
  #mkdir /etc/docker
  #echo "{ \"storage-driver\": \"devicemapper\" }" > /etc/docker/daemon.json 
  sudo systemctl enable docker
  sudo systemctl start docker
  #echo 32000 1024000000  500  32000 > /proc/sys/kernel/sem
}

if [ "$OSLEVEL" == "ubuntu" ]; then
  ubuntu_install
else
  crlinux_install
fi

echo "Complete.."
exit 0
