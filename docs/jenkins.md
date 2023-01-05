# Jenkins

## A. Curious Items

Since Jenkins is running on a Kubernetes cluster, jobs running terraform should
make use of Kubernetes to store its _tfstate_ files as secrets. The example job
at <https://github.com/PentheusLennuye/pipeline_helloworld.git> demonstrates
how.

## B. Postinstall

After Helm deploys Jenkins, some items are optional to get a feel for the
product.

### B.1 Create a test job in GitHub

This has already been done for you, but here is how it is done manually:

#### B.1.1 Set up Jenkins' Kubernetes credentials in Vault

This uses the cluster information used to set up the k8s cluster itself.
Obviously, this would not do in real life.

From the root directory of this project:

```sh
VAULT_TOKEN=$(cat vault-cluster.json | grep jq -r .root_token)
export VAULT_ADDR=https://<your vault fqdn>
vault login $VAULT_TOKEN
CA=$(cat terraform/kubeconfig | grep certificate-authority-data \
  | awk {'print $2'})
CCD=$(cat terraform/kubeconfig | grep client-certificate-data \
  | awk {'print $2'})
CKD=$(cat terraform/kubeconfig | grep client-key-data \
  | awk {'print $2'})
vault kv put kv/ci/tfbackend \
  cluster_ca_certificate=$CA \
  jenkins_k8s_client_certificate=$CCD \
  jenkins_k8s_client_key=$CKD
```

#### B.1.2 Set up the SCM-Pipeline

This pulls an SCM-based Pipeline from a public Git repository. See
[pipeline_helloworld](https://github.com/PentheusLennuye/pipeline_helloworld.git).
You will need to set up some Kubernetes credentials in Vault, so read the
README.md and have at it!

1. Dashboard > Self Tests > + New Item
   - Enter an item name: Hello World
   - Pipeline
   - OK
2. Configure
   - Description: Testing GitHub, K8S and Vault integration
   - Check Discard old builds
     - Strategy: Log Rotation
     - Max # of builds to keep: 5 (or whatever you want)
   - Pipeline
     - Definition: Pipeline script from SCM
     - SCM: Git
       - URL: <https://github.com/PentheusLennuye/pipeline_helloworld.git>
       - Credentials: GitHub Machine Account SCM Credentials
       - Branch specifier: __*/main__
   - Save
3. Build Now
