#!/bin/bash
LOGFILE=/tmp/copyclusterskel.log
exec  > $LOGFILE 2>&1

echo "Got first parameter $1"


source /tmp/icp-bootmaster-scripts/functions.sh

# Figure out the version
# This will populate $org $repo and $tag
parse_icpversion ${1}
echo "org=$org repo=$repo tag=$tag"


docker run --rm -e LICENSE=accept -v /opt/ibm:/data ${org}/${repo}:${tag} cp -r cluster /data
