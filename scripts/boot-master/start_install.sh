#!/bin/bash
source /tmp/icp-bootmaster-scripts/functions.sh

# Figure out the version
# This will populate $org $repo and $tag
parse_icpversion ${1}
echo "org=$org repo=$repo tag=$tag"

docker run --rm -e LICENSE=accept --net=host -t -v /opt/ibm/cluster:/installer/cluster ${org}/${repo}:${tag} install
