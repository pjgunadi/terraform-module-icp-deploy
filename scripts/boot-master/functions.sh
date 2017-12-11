#!/bin/bash
DefaultOrg="ibmcom"
DefaultRepo="icp-inception"

# Populates globals $org $repo $tag
function parse_icpversion() {

  # Determine organisation
  if [[ $1 =~ .*/.* ]]
  then
    org=$(echo ${1} | cut -d/ -f1)
  else
    org=$DefaultOrg
  fi
  
  # Determine repository and tag
  if [[ $1 =~ .*:.* ]]
  then
    repo=$(echo ${1} | cut -d/ -f2 | cut -d: -f1)
    tag=$(echo ${1} | cut -d/ -f2 | cut -d: -f2)
  else
    repo=$DefaultRepo
    tag=$1
  fi
}

