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
    apt install -y glusterfs-server thin-provisioning-tools glusterfs-client
    modprobe dm_thin_pool
    [ -f /etc/modules ] && grep dm_thin_pool /etc/modules || echo dm_thin_pool | tee -a /etc/modules
}
crlinux_install(){
    yum install -y glusterfs-server thin-provisioning-tools glusterfs-client
    modprobe dm_thin_pool
    [ -f /etc/modules-load.d/dm_thin_pool.conf ] && grep dm_thin_pool /etc/modules-load.d/dm_thin_pool.conf || echo dm_thin_pool | tee -a /etc/modules-load.d/dm_thin_pool.conf

}

if [ "$OSLEVEL" == "ubuntu" ]; then
  ubuntu_install
else
  crlinux_install
fi

echo "Complete.."
exit 0
