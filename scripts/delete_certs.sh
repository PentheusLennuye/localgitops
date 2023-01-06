#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
THIS_DIR=$PWD
OS=(uname -s)

read -p "Deleting GitOps Certs [y/N]? " confirm
if [ "$confirm" == "y" ];
  then
    echo "Confirmed deletion. Adios to certificates."
    cd $SCRIPT_DIR/../ansible
    if [ "$OS" == "Darwin" ]; then
      ansible-playbook \
        -e "ca_key_password=$CA_KEY_PASSWORD" \
        delete_ca.yaml || exit $?
    else
      ansible-playbook \
        -e \
        "ansible_become_pass=$SUDO_PASSWORD \
         ca_key_password=$CA_KEY_PASSWORD" \
        delete_ca.yaml || exit $?
    fi
    rm -rf $SCRIPT_DIR/../terraform/certs
    echo "The CA and certs are deleted."
    cd $THIS_DIR
else
    echo "Deletion cancelled."
fi
