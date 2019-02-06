#!/bin/bash
LOGFILE=/tmp/downloadinstaller.log
exec  > $LOGFILE 2>&1

BASEDIR=$(dirname "$0")
icp_source_server=$1
icp_source_user=$2
icp_source_password=$3
icp_source_path=$4
icp_target_path=$5

if [ -n "$icp_source_user" -a -n "$icp_source_password" -a -n "$icp_source_path" -a -n "$icp_target_path" ]; then
  if [[ "${icp_source_path:0:3}" == "s3:" ]]; then
    pip install awscli
    echo -e "${icp_source_user}\n${icp_source_password}\n${icp_source_server}\n" | aws configure
    aws s3 cp ${icp_source_path} ${icp_target_path}
    rm -f ~/.aws/credentials
  else
    echo "Start downloading installation file"
    python $BASEDIR/remote_copy.py $icp_source_server $icp_source_user $icp_source_password $icp_source_path $icp_target_path
    echo "Completed download installation file"
  fi
  # echo "Start loading image to docker"
  # tar xf $icp_target_path -O | sudo docker load #Commented: && rm $icp_target_path
  # echo "Finished loading image to docker"
elif [ -z "$icp_source_user" -a -z "$icp_source_password" -a -n "$icp_source_path" -a -n "$icp_target_path" ]; then
  mv $icp_source_path $icp_target_path
else
  echo "No input for download."
fi
