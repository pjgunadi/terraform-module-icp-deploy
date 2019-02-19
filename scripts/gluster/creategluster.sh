#!/bin/bash
LOGFILE=/tmp/glusterserver.log
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
    sudo apt install -y glusterfs-server thin-provisioning-tools glusterfs-client
    sudo modprobe dm_thin_pool
    [ -f /etc/modules ] && grep dm_thin_pool /etc/modules || echo dm_thin_pool | sudo tee -a /etc/modules
}
crlinux_install(){
    sudo yum install -y glusterfs thin-provisioning-tools glusterfs-fuse
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
