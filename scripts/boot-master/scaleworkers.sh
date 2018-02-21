#!/bin/bash
source /tmp/icp-bootmaster-scripts/functions.sh

ICPDIR=/opt/ibm/cluster 
NEWLIST=/tmp/workerlist.txt
OLDLIST=/opt/ibm/cluster/workerlist.txt

# Figure out the version
# This will populate $org $repo and $tag
parse_icpversion ${1}


# Compare new and old list of workers
declare -a newlist
IFS=', ' read -r -a newlist <<< $(cat ${NEWLIST})

declare -a oldlist
IFS=', ' read -r -a oldlist <<< $(cat ${OLDLIST})

declare -a added
declare -a removed

# As a precausion, if either list is empty, something might have gone wrong and we should exit in case we delete all nodes in error
if [ ${#newlist[@]} -eq 0 ]; then
  echo "Couldn't find any entries in new list of workers. Exiting'"
  exit 1
fi
if [ ${#oldlist[@]} -eq 0 ]; then
  echo "Couldn't find any entries in old list of workers. Exiting'"
  exit 1
fi


# Cycle through old ips to find removed workers
for oip in "${oldlist[@]}"; do
  if [[ "${newlist[@]}" =~ "${oip}" ]]; then
    echo "${oip} is still here"
  fi

  if [[ ! " ${newlist[@]} " =~ " ${oip} " ]]; then
    # whatever you want to do when arr doesn't contain value
    removed+=(${oip})
  fi
done

# Cycle through new ips to find added workers
for nip in "${newlist[@]}"; do
  if [[ "${oldlist[@]}" =~ "${nip}" ]]; then
    echo "${nip} is still here"
  fi

  if [[ ! " ${oldlist[@]} " =~ " ${nip} " ]]; then
    # whatever you want to do when arr doesn't contain value
    added+=(${nip})
  fi
done



if [[ -n ${removed} ]]
then
  echo "removing workers: ${removed[@]}"
  
  ### Setup kubectl
  
  # use kubectl from container
  kubectl="sudo docker run -e LICENSE=accept --net=host -v /opt/ibm/cluster:/installer/cluster -v /root:/root ${org}/${repo}:${tag} kubectl"
  
  $kubectl config set-cluster cfc-cluster --server=https://localhost:8001 --insecure-skip-tls-verify=true 
  $kubectl config set-context kubectl --cluster=cfc-cluster 
  $kubectl config set-credentials user --client-certificate=/installer/cluster/cfc-certs/kubecfg.crt --client-key=/installer/cluster/cfc-certs/kubecfg.key 
  $kubectl config set-context kubectl --user=user 
  $kubectl config use-context kubectl
  
  list=$(IFS=, ; echo "${removed[*]}")
 
  for ip in "${removed[@]}"; do
    $kubectl drain $ip --force
    docker run -e LICENSE=accept --net=host -v "$ICPDIR":/installer/cluster ${org}/${repo}:${tag} uninstall -l $ip
    $kubectl delete node $ip
    sudo sed -i "/^${ip}.*$/d" /etc/hosts
    sudo sed -i "/^${ip}.*$/d" /opt/ibm/cluster/hosts
  done
  
fi

if [[ -n ${added} ]]
then
  echo "Adding: ${added[@]}"
  # Collect node names
  
  # Update /etc/hosts
  for node in "${added[@]}" ; do
    nodename=$(ssh -o StrictHostKeyChecking=no -i ${ICPDIR}/ssh_key ${node} hostname)
    printf "%s     %s\n" "$node" "$nodename" | cat - /etc/hosts | sudo sponge /etc/hosts
    printf "%s     %s\n" "$node" "$nodename" | ssh -o StrictHostKeyChecking=no -i ${ICPDIR}/ssh_key ${node} 'cat - /etc/hosts | sudo sponge /etc/hosts'
  done

  list=$(IFS=, ; echo "${added[*]}")
  docker run -e LICENSE=accept --net=host -v "/opt/ibm/cluster":/installer/cluster \
  ${org}/${repo}:${tag} install -l ${list}  
fi


# Backup the origin list and replace
mv ${OLDLIST} ${OLDLIST}-$(date +%Y%m%dT%H%M%S)
mv ${NEWLIST} ${OLDLIST}
