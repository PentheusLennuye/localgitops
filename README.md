# Local GitOps

## A. Introduction

GitOps is easier to learn when one has the tools already at hand.

GitOps is an extension of DevOps. It is used for infrastructure deployment.
GitOps is the technical side of DevOps, and includes:

- Deployment platforms such as VMWare or Kubernetes
- Orchestrator services that use Ansible, Terraform or Kubernetes
- CI/CD pipeline servers such as Jenkins, CircleCI or Travis
- Supporting services such as secret services and repositories.

Language build tools such as maven, compilers, and artifact servers for
pre-compiled binaries are not strictly part of GitOps, more for software
development. However, artifact servers for deployment packages and containers
_are_ needed when installing versioned software into production.

DevOps in turn can use the systems furnished by GitOps for their software CI/CD.

### A.1. Contents of this project

For this local gitops-in-a-laptop system, we have a:

- Deployment platform: Kubernetes on Docker, using K3D
- CI/CD pipeline server: A single-node Jenkins, preconfigured with
  - useful plugins defined in _ansible/files/plugins.jenkins.txt_ and
  - its own Kubernetes host defined as a Cloud for pipeline agents.
- Secret Store: Hashicorp Vault
- Artifact Repository: Harbor
- A load balancer, Traefik, handling external traffic.
- A troubleshooting image within the cluster called "Network Multitool,"
  courtesy of the _wbitt_ GitHub repository.

#### A.1.1 No Orchestrator?

There are no orchestrators yet. Those will be Docker images using any
combination of Helm, kubectl, and Terraform that you might wish to create.

Hint: Look up [kaniko](https://github.com/GoogleContainerTools/kaniko) as a
start.

## B. Prerequisites

The following is not automated. They are needed to automate the deployment
of this project.

### B.1 Cloud

Ensure you have a GitHub machine account created. GitHub permits an individual
a personal account and a machine account. While logged into GitHub, create a
token with the correct scope for CI/CD operations:

- repo
- write:packages
- admin:org: read:org
- admin:repo_hook
- user: read:user, user:email
- delete_repo

at <https:/github.com/settings/tokens>

### B.2 Mac OS X

- Docker Desktop with VirtioFS file sharing turned on[^1]
- Homebrew, configured to install to local user
- Ansible >= 2.13
- pip3 with the 'cryptography' library installed

### B.3. Linux

- Docker
- Ansible >= 2.13
- pip3
- yum-utils (for the RedHat family)

## C. Create the Infrastructure

### C.1 Configure the Environment Variables

1. Think of three aliases for 'localhost' that would be used for K8S, Jenkins,
   Vault, Harbor Core, and Harbor Notary. Something like k8s, jenkins, vault,
   harbor, and harbor-notary. Set also the domain, ensuring that it has two
   levels (for certificate reasons).
   - On Linux: Set these in _ansible/host_vars/localhost.yaml:k3d:hostname*_.
     These will be added to _/etc/hosts_ automatically.
   - On Mac: Set the aliases in /etc/hosts on the line starting with 127.0.0.1.
     Set it also in _ansible/host_vars/localhost.yaml:k3d:hostname*_.

2. Set the CA_KEY_PASSWORD environment variable to generate the local domain
   certificates. If it is not set, the script will ask for it.

3. Set the JENKINS_ADMIN_USER, JENKINS_ADMIN_PASSWORD, and HARBOR_ADMIN_PASSWORD
   environment variables for logging as an admin into Jenkins and Harbor
   respectively. If these are not set, the script will ask for them.

4. Set the GITHUB_URL and GITHUB_MACHINE_TOKEN environment variables. Similarly
   to (2), if they are not set, they will be requested. The token is for a
   machine account on GitHub (or Enterprise). See docs/jenkins.md for token
   access settings.

5. Set the SQL_PASSWORD and REDIS_PASSWORD environment variables. Similarly to
   (2), if they are not set, they will be requested. These are the master
   passwords for PostgreSQL and Redis used by Harbor.

### C.2 Deploy

#### C.2.1 LocalGitOps CA Certificate

The load balancer uses https. In order to use command-line tools on Vault,
Jenkins and Harbor ... and to have a successful implementation. You will need
to generate and import a localgitops CA certificate.

Execute `./genca.sh`

To delete all the certificates, including the ones for the services, execute:
`scripts/delete_certs.sh`

#### C.2.2 Everything Else

1. If at home, warn everyone that the Internet is going to slow down. There
   will be much simultaneous image downloading.
2. Execute `./deploy.sh`

This will take a long time but not as much as half an hour. It creates
subdirectories under _volumes_ to be used for Kubernetes local filesystem
storage (see D.4), populates terraform modules under _terraform_, and executes
terraform in each module.

### C.3 Security Considerations

The script will insert the local Kubernetes cluster configuration in your
_~/.kube/config_.

The deployments create two files that really should not be published anywhere,
even if running for local experimention:

- _vault-keys.json,_ containing Vault keys. One will need this when unsealing
  the Vault.
- _terraform/kubeconfig_, containing the k8s admin cert and key. This gets fed
  into Jenkins so it can use its own Kubernetes control plane for Kubernetes
  agents.

Since this project is _supposed to be for local experimentation_, make use of
those files all you want, but for the sake of all that is holy don't use them
in production.

## D. Use the Infrastructure

### D.1 URLs

- Harbor is at `https://(your local harbor fqdn)`
- Jenkins is at `https://(your local jenkins fqdn)`
- Vault is at `https://(your local vault fqdn)`

### D.2 Logging In

- Mozilla does not appear to use the system trust store. You may wish to import
  the ca certificate in cacerts into your browser using its own settings.

- Log into Jenkins with the credentials set in the _JENKINS*_ environment
  variables.

- To log into Harbor for the first time, use __admin__ as the username.

- To use Docker to access Harbor, use `docker login <harbor fqdn>`

- Vault is mostly vanilla, so the only way to log in for the first time is
  with the root token. To get the root token, execute:

  ```bash
  cat vault-keys.json | jq -r .root_token
  ```

### D.3 Troubleshooting

#### D.3.1 Network troubleshooting
When all hell breaks loose, one can log into the network multitool image to dig
around with a standard set of Linux utilities:

```bash
MULTITOOL=$(kubectl get pods | grep '^multitool-' | awk '{print $1}')
kubectl exec -it $MULTITOOL -- bash

# First time only
update-ca-certificates
```

#### D.3.2 Docker troubleshooting

For docker issues to Harbor, use the docker image:

```bash
DOCKER=$(kubectl get pods | grep '^docker-' | awk '{print $1}')
kubectl exec -it $DOCKER -- sh

# First time only
update-ca-certificates

# Consequently
docker login <docker fqdn>  # Same as on the workstation
```

### D.4 Files

A laptop generally does not have a SAN, a NAS, or an iSCSI array going around
with it. This system, therefore, uses disk-based persistent storage for its
jobs, databases, secrets, and artifacts. The components of this system are
stored as follows:

- Jenkins: ./volumes/pv1
- Vault: ./volumes/pv2
- PostgreSQL (used by Harbor): ./volumes/pv3
- Harbor: ./volumes/{pv4 pv5 pv6}

In the case of Harbor, it needs separate volumes for its Registry, ChartMuseum,
and JobService services, respectively.

### D.3 Example Jobs

- You can fire the vault_test job located in the Self Tests folder.
- Look in _docs/jenkins_ for an example of setting up an SCM-fired pipeline
  from a GitHub repository.

## E. Stop, Start, Destroy

- Stop: `k3d cluster stop localgitops`
- Start: `k3d cluster start localgitops`
- Delete: `scripts/destroy_cluster.sh`
  This last one can be painful; when the cluster goes, so do all the helm
  charts and downloaded images. Considering a great amount of time and
  bandwidth it takes to set up, perhaps learning Kubernetes troubleshooting
  would be worth it.

## F. Bugs

- Helm Notary causes 500 Server Errors, so it is turned off for now.
- The Traefik Load Balancer won't work (throwing HTTP 404 errors) until
  Jenkins' _ingress service_ is operating. Vault and Harbor are affected.
- There is a warning on _default_secret_name_ used in the jenkins service
  account resource. Kubernetes secret will need to be used to autogenerate
  a secret name in a future build.

[^1]: As of Q1 2023, the default is the traditional _gRPC FUSE_. It is not as awful as the original _oxsfx_. but it is still painful.
