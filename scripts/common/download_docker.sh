#!/bin/bash
LOGFILE=/tmp/download_install_docker.log
exec  > $LOGFILE 2>&1

BASEDIR=$(dirname "$0")
docker_src_server=$1
docker_src_user=$2
docker_src_password=$3
docker_src_path=$4
docker_tgt_path=$5

if [ -n "$docker_src_user" -a -n "$docker_src_password" -a -n "$docker_src_path" -a -n "$docker_tgt_path" ]; then
  if [[ "${docker_src_path:0:3}" == "s3:" ]]; then
    pip install awscli
    echo -e "${docker_src_user}\n${docker_src_password}\n${docker_src_server}\n" | aws configure
    aws s3 cp ${docker_src_path} ${docker_tgt_path}
    rm -f ~/.aws/credentials
  else
    echo "Start downloading installation file"
    python $BASEDIR/remote_copy.py $docker_src_server $docker_src_user $docker_src_password $docker_src_path $docker_tgt_path
    echo "Completed download installation file"
  fi
elif [ -z "$docker_src_user" -a -z "$docker_src_password" -a -n "$docker_src_path" -a -n "$docker_tgt_path" ]; then
  mv $docker_src_path $docker_tgt_path
else
  echo "No input for download."
fi

if [ -n "$docker_tgt_path" -a -f "$docker_tgt_path" ]; then
  chmod +x $docker_tgt_path
  sudo $docker_tgt_path --install
fi