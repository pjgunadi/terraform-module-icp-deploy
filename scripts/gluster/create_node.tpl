#!/bin/bash
CLUSTERNAME=$(heketi-cli --user admin --secret ${heketi_admin_pwd} cluster list | awk -F: -v key="Id" '$1==key {print $2}' | awk -F" " '{print $1}')
NODEIP="${nodeip}"
NODEFILE="${nodefile}"
if [ -n "$CLUSTERNAME" ]; then
  heketi-cli --user admin --secret ${heketi_admin_pwd} node add --zone=1 --cluster=$CLUSTERNAME --management-host-name=$NODEIP --storage-host-name=$NODEIP | awk -F: -v key="Id" '$1==key {print $2}' | tee $NODEFILE
  heketi-cli --user admin --secret ${heketi_admin_pwd} device add --name=${device_name} --node=$(cat $NODEFILE | sed -e 's/^[ \t]*//')
fi