#!/bin/bash
#This script updates hosts with required prereqs
#if [ $# -lt 1 ]; then
#  echo "Usage $0 <hostname>"
#  exit 1
#fi

#HOSTNAME=$1

LOGFILE=/tmp/prereqs.log
exec 3>&1
exec > >(tee -a ${LOGFILE} >/dev/null) 2> >(tee -a ${LOGFILE} >&3)

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

  sudo rm /var/cache/apt/archives/lock
  sudo rm  /var/lib/apt/lists/lock
  sudo dpkg --configure -a
  sudo apt-get clean
  sudo apt-get install -f
  sudo apt-get update

  packages_to_check="\
python-yaml thin-provisioning-tools lvm2 \
apt-transport-https nfs-common ca-certificates curl software-properties-common \
python python-pip socat unzip moreutils"
  packages_to_install=""

  for package in ${packages_to_check}; do
    if ! dpkg -l ${package} &> /dev/null; then
      packages_to_install="${packages_to_install} ${package}"
    fi
  done

  if [ ! -z "${packages_to_install}" ]; then
    # attempt to install, probably won't work airgapped but we'll get an error immediately
    echo "Attempting to install: ${packages_to_install} ..."
    retries=20
    sudo apt-get update
    while [ $? -ne 0 -a "$retries" -gt 0 ]; do
      retries=$((retries-1))
      echo "Another process has acquired the apt-get update lock; waiting 10s" >&2
      sleep 10;
      sudo apt-get update
    done
    if [ $? -ne 0 -a "$retries" -eq 0 ] ; then
      echo "Maximum number of retries (${retries}) for apt-get update attempted; quitting" >&2
      exit 1
    fi

    retries=20
    export DEBIAN_FRONTEND=noninteractive
    export DEBIAN_PRIORITY=critical
    sudo -E apt-get -yq -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" upgrade
    while [ $? -ne 0 -a "$retries" -gt 0 ]; do
      retries=$((retries-1))
      echo "Another process has acquired the apt-get install/upgrade lock; waiting 10s" >&2
      sleep 10;
      sudo -E apt-get -yq -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" upgrade
    done
    
    retries=20
    sudo apt-get install -y ${packages_to_install}
    while [ $? -ne 0 -a "$retries" -gt 0 ]; do
      retries=$((retries-1))
      echo "Another process has acquired the apt-get install/upgrade lock; waiting 10s" >&2
      sleep 10;
      sudo apt-get install -y ${packages_to_install}
    done
    if [ $? -ne 0 -a "$retries" -eq 0 ] ; then
      echo "Maximum number of retries (20) for apt-get install attempted; quitting" >&2
      exit 1
    fi
  fi

  if ! docker --version ; then
    retries=20
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt-get install -y docker-ce
    while [ $? -ne 0 -a "$retries" -gt 0 ]; do
      retries=$((retries-1))
      echo "Another process has acquired the apt-get install/upgrade lock; waiting 10s" >&2
      sleep 10;
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
      sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
      sudo apt-get install -y docker-ce
    done
    if [ $? -ne 0 -a "$retries" -eq 0 ] ; then
      echo "Maximum number of retries (20) for apt-get install attempted; quitting" >&2
      exit 1
    fi
  fi
  sudo service iptables stop
  sudo ufw disable
  sudo pip install --upgrade pip
  sudo pip install pyyaml paramiko
  sudo service docker start
}

crlinux_install(){
  echo "vm.max_map_count=262144" | sudo tee /etc/sysctl.d/90-icp.conf
  echo "net.ipv4.ip_local_port_range=10240 60999" | sudo tee -a /etc/sysctl.d/90-icp.conf
  sudo sysctl -p /etc/sysctl.d/90-icp.conf

  packages_to_check="\
PyYAML device-mapper libseccomp libtool-ltdl libcgroup iptables device-mapper-persistent-data lvm2 \
python-setuptools policycoreutils-python socat unzip nfs-utils yum-utils"

  for package in ${packages_to_check}; do
    if ! rpm -q ${package} &> /dev/null; then
      packages_to_install="${packages_to_install} ${package}"
    fi
  done

  if [ ! -z "${packages_to_install}" ]; then
    # attempt to install, probably won't work airgapped but we'll get an error immediately
    echo "Attempting to install: ${packages_to_install} ..."
    #sudo yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
    sudo yum install -y ${packages_to_install}
  fi

  if ! docker --version ; then
    sudo rpm -ivh http://mirror.centos.org/centos/7/extras/x86_64/Packages/container-selinux-2.21-1.el7.noarch.rpm
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo yum -y install docker-ce
  fi

  #Disable SELINUX
  sudo sed -i s/^SELINUX=enforcing/SELINUX=disabled/ /etc/selinux/config && sudo setenforce 0
  sudo systemctl disable firewalld
  sudo systemctl stop firewalld

  sudo easy_install pip
  sudo pip install pyyaml paramiko
  sudo systemctl enable docker
  sudo systemctl start docker
}

if [ "$OSLEVEL" == "ubuntu" ]; then
  ubuntu_install
else
  crlinux_install
fi

echo "Complete.."
exit 0
