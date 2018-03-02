#!/bin/bash
WORKDIR=/opt/ibm/cluster 
ICPDIR=$WORKDIR

# Make sure ssh key has correct permissions set before using
chmod 600 ${WORKDIR}/ssh_key

## First compile a list of all nodes in the cluster with ip addresses and associated hostnames
declare -a master_ips
IFS=', ' read -r -a master_ips <<< $(cat ${WORKDIR}/masterlist.txt)

declare -a worker_ips
IFS=', ' read -r -a worker_ips <<< $(cat ${WORKDIR}/workerlist.txt)

declare -a proxy_ips
IFS=', ' read -r -a proxy_ips <<< $(cat ${WORKDIR}/proxylist.txt)

## First gather all the hostnames and link them with ip addresses
declare -A cluster

declare -A workers
for worker in "${worker_ips[@]}"; do
  workers[$worker]=$(ssh -o StrictHostKeyChecking=no -i ${WORKDIR}/ssh_key ${worker} hostname)
  cluster[$worker]=${workers[$worker]}
  printf "%s     %s\n" "$worker" "${cluster[$worker]}" >> /tmp/hosts
done

declare -A proxies
for proxy in "${proxy_ips[@]}"; do
  proxies[$proxy]=$(ssh -o StrictHostKeyChecking=no -i ${WORKDIR}/ssh_key ${proxy} hostname)
  cluster[$proxy]=${proxies[$proxy]}
  printf "%s     %s\n" "$proxy" "${cluster[$proxy]}" >> /tmp/hosts
done

declare -A masters
for m in "${master_ips[@]}"; do
  # No need to ssh to self
  if [[ "$m" == "${master_ips[0]}" ]]
  then
    masters[$m]=$(hostname)
  else
    masters[$m]=$(ssh -o StrictHostKeyChecking=no -i ${WORKDIR}/ssh_key ${m} hostname)
  fi
  cluster[$m]=${masters[$m]}
  printf "%s     %s\n" "$m" "${cluster[$m]}" >> /tmp/hosts
done

# Add management nodes if separate from master nodes
if [[ -s ${WORKDIR}/managementlist.txt ]]
then
  declare -a management_ips
  IFS=', ' read -r -a management_ips <<< $(cat ${WORKDIR}/managementlist.txt)
  
  declare -A mngrs
  for m in "${management_ips[@]}"; do
    mngrs[$m]=$(ssh -o StrictHostKeyChecking=no -i ${WORKDIR}/ssh_key ${m} hostname)
    cluster[$m]=${mngrs[$m]}
    printf "%s     %s\n" "$m" "${cluster[$m]}" >> /tmp/hosts
  done
fi

## Update all hostfiles in all nodes in the cluster
for node in "${!cluster[@]}"; do
  # No need to ssh to self
  if [[ "$node" == "${master_ips[0]}" ]]
  then
    cat /tmp/hosts | cat - /etc/hosts | sudo sponge /etc/hosts
  else
    cat /tmp/hosts | ssh -i ${WORKDIR}/ssh_key ${node} 'cat - /etc/hosts | sudo sponge /etc/hosts'
  fi
done

## Generate the hosts file for the ICP installation
echo '[master]' > ${ICPDIR}/hosts
for master in "${master_ips[@]}"; do
  echo $master >> ${ICPDIR}/hosts
done

echo  >> ${ICPDIR}/hosts
echo '[worker]' >> ${ICPDIR}/hosts
for worker in "${worker_ips[@]}"; do
  echo $worker >> ${ICPDIR}/hosts
done

echo  >> ${ICPDIR}/hosts
echo '[proxy]' >> ${ICPDIR}/hosts
for proxy in "${proxy_ips[@]}"; do
  echo $proxy >> ${ICPDIR}/hosts
done

# Add management host entries if separate from master nodes
if [[ ! -z ${management_ips} ]]
then
  echo  >> ${ICPDIR}/hosts
  echo '[management]' >> ${ICPDIR}/hosts
  for m in "${management_ips[@]}"; do
    echo $m >> ${ICPDIR}/hosts
  done
fi
