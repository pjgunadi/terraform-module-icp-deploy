#!/bin/bash
CLUSTERNAME=$(heketi-cli cluster list | awk -F: -v key="Id" '$1==key {print $2}')
NODEIP="${nodeip}"
NODEFILE="${nodefile}"
if [ -n "$CLUSTERNAME" ]; then
  heketi-cli node add --zone=1 --cluster=$CLUSTERNAME --management-host-name=$NODEIP --storage-host-name=$NODEIP | awk -F: -v key="Id" '$1==key {print $2}' | tee $NODEFILE
  heketi-cli device add --name=${device_name} --node=$(cat $NODEFILE | sed -e 's/^[ \t]*//')
fi