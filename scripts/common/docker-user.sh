#!/bin/bash

# Some RHEL based installations may not have docker installed yet.
# Only aattempt to add user to group if docker is installed and the user is not root
if grep -q docker /etc/group
then
  iam=$(whoami)

  if [[ $iam != "root" ]]
  then
    sudo usermod -a -G docker $iam
  fi
fi