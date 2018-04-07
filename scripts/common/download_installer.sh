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
    cat <<EOF | tee ~/.aws/credentials
[default]
aws_access_key_id = ${icp_source_user}
aws_secret_accesskey = ${icp_source_password}
EOF
    aws --endpoint-url=${icp_source_server} s3 cp ${icp_source_path} ${icp_target_path}
    rm -f ~/.aws/credentials
  else
    echo "Start downloading installation file"
    python $BASEDIR/remote_copy.py $icp_source_server $icp_source_user $icp_source_password $icp_source_path $icp_target_path
    echo "Completed download installation file"
  fi
  echo "Start loading image to docker"
  tar xf $icp_target_path -O | sudo docker load && rm $icp_target_path
  echo "Finished loading image to docker"
else
  echo "No input for download."
fi
