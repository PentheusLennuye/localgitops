#!/bin/bash

echo "Create CA certificate"
OS=$(uname -s)

# Ensure environment variables are set
while [ -z $CA_KEY_PASSWORD ];
do
  read -s -p "Enter the CA_KEY_PASSWORD for ssl cert generation: " ckp
  echo
  if [ "$ckp" == "" ]; then
    continue
  fi
  read -s -p "Confirm CA_KEY_PASSWORD: " cckp
    echo
  if [ "$ckp" == "$cckp" ]; then
    export CA_KEY_PASSWORD=$ckp
  else
    echo "Passwords do not match"
  fi
done

# Query sudo password for ansible "become" requirements
if [ "$OS" != "Darwin" ]; then
  while [ -z $SUDO_PASSWORD ];
  do
    read -s -p "Enter localhost SUDO_PASSWORD: " sp
    echo
    if [ "$sp" == "" ]; then
      continue
    fi
    export SUDO_PASSWORD=sp
  done
fi

THISDIR=$PWD
cd ansible
if [ "$OS" == "Darwin" ]; then
  ansible-playbook \
    -e "ca_key_password=$CA_KEY_PASSWORD" \
    create_ca.yaml || exit $?
else
  ansible-playbook \
   -e \
   "ansible_become_pass=$SUDO_PASSWORD \
   ca_key_password=$CA_KEY_PASSWORD" \
   create_ca.yaml || exit $?
fi
cd $THISDIR

echo "CA certificate created in cacerts/"
if [ "$OS" == "Darwin" ]; then
  echo "Please run keychain and import the ca cert, then mark it 'trusted.'"
  echo ">cacerts/localgitops-ca.pem"
else
  echo "Ubuntu and Fedora have the cert imported into the system trusted ca-certificates."
  echo "Mozilla does not use the system store; please import cacerts/*localgitops-ca.pem"
fi
