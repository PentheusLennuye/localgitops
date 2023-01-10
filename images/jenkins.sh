#!/bin/bash

mkdir -p config
cp ../cacerts/localgitops-ca.pem config/
cp ../ansible/file/plugins.jenkins.txt config/

# From ansible: send casc here as well.

# This sucker is going to be 433MB
docker build . -f Dockerfile.jenkins -t harbor.gitops.local/jenkins:lts
echo $HARBOR_ADMIN_PASSWORD | \
  docker login -u admin --password-stdin harbor.gitops.local
docker push harbor.gitops.local/library/jenkins:lts

