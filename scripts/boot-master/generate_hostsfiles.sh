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

declare -a boot_ips
IFS=', ' read -r -a boot_ips <<< $(cat ${WORKDIR}/bootlist.txt)

## First gather all the hostnames and link them with ip addresses
declare -A cluster

declare -A workers
for worker in "${worker_ips[@]}"; do
  workers[$worker]=$(ssh -o StrictHostKeyChecking=no -i ${WORKDIR}/ssh_key ${worker} hostname)
  if [ "${workers[$worker]}" != "" -a "${cluster[$worker]}" == "" ]; then
    cluster[$worker]=${workers[$worker]}
    printf "%s     %s     %s\n" "$worker" "${cluster[$worker]}" "$(echo ${cluster[$worker]} | cut -d '.' -f1)" >> /tmp/hosts
  fi
done

declare -A proxies
for proxy in "${proxy_ips[@]}"; do
  proxies[$proxy]=$(ssh -o StrictHostKeyChecking=no -i ${WORKDIR}/ssh_key ${proxy} hostname)
  if [ "${proxies[$proxy]}" != "" -a "${cluster[$proxy]}" == "" ]; then
    cluster[$proxy]=${proxies[$proxy]}
    printf "%s     %s     %s\n" "$proxy" "${cluster[$proxy]}" "$(echo ${cluster[$proxy]} | cut -d '.' -f1)" >> /tmp/hosts
  fi
done

declare -A masters
for m in "${master_ips[@]}"; do
  masters[$m]=$(ssh -o StrictHostKeyChecking=no -i ${WORKDIR}/ssh_key ${m} hostname)
  if [ "${masters[$m]}" != "" -a "${cluster[$m]}" == "" ]; then
    cluster[$m]=${masters[$m]}
    printf "%s     %s     %s\n" "$m" "${cluster[$m]}" "$(echo ${cluster[$m]} | cut -d '.' -f1)" >> /tmp/hosts
  fi
done

declare -A boots
for b in "${boot_ips[@]}"; do
  boots[$b]=$(ssh -o StrictHostKeyChecking=no -i ${WORKDIR}/ssh_key ${b} hostname)
  if [ "${boots[$b]}" != "" -a "${cluster[$b]}" == "" ]; then
    cluster[$b]=${boots[$b]}
    printf "%s     %s     %s\n" "$b" "${cluster[$b]}" "$(echo ${cluster[$b]} | cut -d '.' -f1)" >> /tmp/hosts
  fi
done

# Add management nodes if separate from master nodes
if [[ -s ${WORKDIR}/managementlist.txt ]]
then
  declare -a management_ips
  IFS=', ' read -r -a management_ips <<< $(cat ${WORKDIR}/managementlist.txt)
  
  declare -A mngrs
  for mg in "${management_ips[@]}"; do
    mngrs[$mg]=$(ssh -o StrictHostKeyChecking=no -i ${WORKDIR}/ssh_key ${mg} hostname)
    if [ "${mngrs[$mg]}" != "" -a "${cluster[$mg]}" == "" ]; then
      cluster[$mg]=${mngrs[$mg]}
      printf "%s     %s     %s\n" "$mg" "${cluster[$mg]}" "$(echo ${cluster[$mg]} | cut -d '.' -f1)" >> /tmp/hosts
    fi
  done
fi

# Add VA nodes if required
if [[ -s ${WORKDIR}/valist.txt ]]; then
  declare -a va_ips
  IFS=', ' read -r -a va_ips <<< $(cat ${WORKDIR}/valist.txt)
  
  declare -A vas
  for v in "${va_ips[@]}"; do
    vas[$v]=$(ssh -o StrictHostKeyChecking=no -i ${WORKDIR}/ssh_key ${v} hostname)
    if [ "${vas[$v]}" != "" -a "${cluster[$v]}" == "" ]; then
      cluster[$v]=${vas[$v]}
      printf "%s     %s     %s\n" "$v" "${cluster[$v]}" "$(echo ${cluster[$v]} | cut -d '.' -f1)" >> /tmp/hosts
    fi
  done
fi

## Update all hostfiles in all nodes in the cluster
cat /tmp/hosts | sudo tee -a /etc/hosts
for node in "${!cluster[@]}"; do
  if [ "$node" != "$(hostname)" ]; then
    cat /tmp/hosts | ssh -i ${WORKDIR}/ssh_key ${node} 'sudo tee -a /etc/hosts'
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

# Add VA host entries if required
if [[ ! -z ${va_ips} ]]
then
  echo  >> ${ICPDIR}/hosts
  echo '[va]' >> ${ICPDIR}/hosts
  for v in "${va_ips[@]}"; do
    echo $v >> ${ICPDIR}/hosts
  done
fi