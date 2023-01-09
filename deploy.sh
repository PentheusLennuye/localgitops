#!/bin/bash

THISDIR=$PWD
TF_CLI_CONFIG_FILE=$THISDIR/terraform/localgitops.tfrc

install_ansible_community () {
  # Install ansible community.general and kubernetes.core
  echo -n 'Installing ansible collections at need...'
  for collection in community.general kubernetes.core; do
    (ansible-galaxy collection list | grep "$collection" >/dev/null 2>&1) || \
      ansible-galaxy collection install $collection
  done
  echo 'done'
}

install_packages () {
  cd $THISDIR/ansible
  if [ "$OS" == "Darwin" ]; then
    ansible-playbook install_packages.yaml || exit $?
  else
    ansible-playbook -e "ansible_become_pass=$SUDO_PASSWORD" \
      install_packages.yaml || exit $?
  fi
}

fill_variables_and_configs () {
  cd $THISDIR/ansible
  ansible-playbook \
    -e \
    "jenkins_admin_id=$JENKINS_ADMIN_USER \
    jenkins_admin_password=$JENKINS_ADMIN_PASSWORD \
    harbor_admin_password=$HARBOR_ADMIN_PASSWORD \
    openldap_admin_username=$OPENLDAP_ADMIN_USER \
    openldap_admin_password=$OPENLDAP_ADMIN_PASSWORD \
    openldap_bind_password=$OPENLDAP_BIND_PASSWORD \
    redis_password=$REDIS_PASSWORD \
    sql_username=$SQL_USERNAME \
    sql_password=$SQL_PASSWORD \
    ca_key_password=$CA_KEY_PASSWORD \
    github_url=$GITHUB_URL \
    github_machine_token=$GITHUB_MACHINE_TOKEN" \
    create_terraform_config.yaml || exit $?
}

create_k3d_cluster () {
  echo -n "Deploying K3D cluster..."
  cd $THISDIR/terraform/cluster
  terraform init || exit $?
  terraform plan -out .the.plan || exit $?
  terraform apply .the.plan || exit $?
  sleep 5 
  echo "Awaiting for coredns to deploy"
  kubectl wait pods -n kube-system -l k8s-app=kube-dns --for condition=Ready \
    --timeout=60s

  echo "Making the kubeconfig available for integration"
  /usr/local/bin/k3d kubeconfig get localgitops > $THISDIR/terraform/kubeconfig
  cd $THISDIR/terraform/populate
  sed 's/:6445//' $THISDIR/terraform/kubeconfig > jenkins_kubeconfig
}

adjust_k3d_networking () {
  echo -n "Adjusting K3D networking..."
  cd $THISDIR/terraform/networking
  terraform init || exit $?
  terraform plan -out .the.plan || exit $?
  terraform apply .the.plan || exit $?
  echo "adjusted."
  echo "Restarting CoreDNS to enable rewrites"
  kubectl -n kube-system rollout restart deployment coredns
  kubectl wait pods -n kube-system -l k8s-app=kube-dns --for condition=Ready \
    --timeout=30s
}

deploy_services () {
  echo -n "Deploying services on cluster..."
  cd $THISDIR/terraform/services
  terraform init || exit $?
  terraform plan -out .the.plan || exit $?
  terraform apply .the.plan || exit $?
  echo "deployed."

  echo "Unsealed. Now waiting up to 3 minutes for Jenkins to start"
  kubectl wait pods -n jenkins -l app=jenkins-server --for condition=Ready \
    --timeout=180s
  jpod=$(kubectl get pods -n jenkins | grep '^jenkins-' | awk '{print $1}')
  kubectl cp config/casc.yaml jenkins/$jpod:/var/jenkins_home/casc.yaml \
    || exit $?

  cd $THISDIR
  echo -n "Unsealing Vault..."
  [ -f vault-keys.json ] || \
    kubectl exec -n vault vault-0 -- vault operator init \
      -key-shares=1 -key-threshold=1 -format=json > vault-keys.json
  export VAULT_UNSEAL_KEY=$(jq -r '.unseal_keys_b64[]' vault-keys.json)
  kubectl exec -n vault vault-0 -- vault operator unseal $VAULT_UNSEAL_KEY
}

install_jenkins_plugins () {
  cd $THISDIR/terraform/services/config
  [ ! -f .plugin ] &&
  {
  echo "Installing plugins and rebooting Jenkins"
  jpod=$(kubectl get pods -n jenkins | grep '^jenkins-' | awk '{print $1}')
  kubectl cp plugins.jenkins.txt jenkins/$jpod:/tmp/plugins.txt || exit $?
  kubectl exec -it -n jenkins $jpod -- bash -c \
    "/bin/jenkins-plugin-cli -d \$JENKINS_HOME/plugins --plugins \
    -f /tmp/plugins.txt" 

  echo "Rolling restart to force plugin downloads, up to 5min"
  kubectl -n jenkins rollout restart deployment jenkins
  kubectl wait pods -n jenkins -l app=jenkins-server --for condition=Ready \
    --timeout=300s
  echo "Waiting another 30s for Jenkins latency after deploy."
  sleep 30
  touch .plugin
  }
}

populate_services () {
  cd $THISDIR/terraform/populate
  echo "Configuring Vault and Jenkins Integration"
  terraform init
  terraform plan -out .the.plan || exit $?
  terraform apply .the.plan || exit $?

  MULTITOOL=$(kubectl get pods | grep '^multitool-' | awk '{print $1}')
  kubectl exec $MULTITOOL -- update-ca-certificates > /dev/null 2>&1

  DOCKER=$(kubectl get pods | grep '^docker-' | awk '{print $1}')
  kubectl exec $DOCKER -- update-ca-certificates > /dev/null 2>&1
}

echo "Local GitOps Pipeline"
source scripts/set_environment_variables
install_ansible_community
install_packages
fill_variables_and_configs
create_k3d_cluster
adjust_k3d_networking
deploy_services
install_jenkins_plugins
populate_services
echo "Deployment complete"
