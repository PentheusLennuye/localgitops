#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

read -p "Deleting GitOps Cluster and volumes [y/N]? " confirm
if [ "$confirm" == "y" ];
  then
    echo "Confirmed deletion. Adios, amigo. そよなら."
    k3d cluster delete localgitops
    rm vault-keys.json
    rm $SCRIPT_DIR/../terraform/services/config/.plugin
    rm $SCRIPT_DIR/../terraform/kubeconfig
    for segment in cluster networking services populate; do
      rm -rf $SCRIPT_DIR/../terraform/$segment/terraform.tfstate*
    done  # Leave the terraform and plugin-cache. Downloads are expensive!
    uname -s | grep Linux && sudo chown -R $USER volumes
    rm -rf volumes
    echo "The cluster and volumes are deleted."
    echo "CA and certs as well as the plugin-cache remain."
else
    echo "Deletion cancelled."
fi
