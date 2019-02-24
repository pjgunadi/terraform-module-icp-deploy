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

    #Workaround Ubuntu use glusterfs-server instead of glusterd, Heketi expect glusterd service name
    GLUSTERD_FILE="/etc/init.d/glusterfs-server"
    OLD_SVCNAME="glusterfs-server"
    NEW_SVCNAME="glusterd"
    sudo systemctl list-units|grep $NEW_SVCNAME
    if [ "$?" != "0" ]; then
      echo "Updating daemon from $OLD_SVCNAME to $NEW_SVCNAME"
      if [ -s $GLUSTERD_FILE ]; then
        sudo sed -i "s/$OLD_SVCNAME/$NEW_SVCNAME/" $GLUSTERD_FILE
        sudo systemctl daemon-reload
      fi
    fi
}
crlinux_install(){
    sudo yum install -y thin-provisioning-tools glusterfs-fuse glusterfs-server
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
