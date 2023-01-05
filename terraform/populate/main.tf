terraform {
  required_providers {
    jenkins = {
      source = "taiidani/jenkins"
      version = "0.9.3"
    }
    vault = {
      source = "hashicorp/vault"
      version = "3.10.0"
    }
    time = {
      source = "hashicorp/time"
      version = "0.9.1"
    }
  }
}

provider "jenkins" {
  server_url = "https://jenkins.gitops.local"
  username = var.jenkins_admin_id
  password = var.jenkins_admin_password
  ca_cert = "${path.module}/../../cacerts/localgitops-ca.pem"
}

provider "vault" {
  address = "https://vault.gitops.local"
  token = jsondecode(file("../../vault-keys.json"))["root_token"]
  ca_cert_file = "${path.module}/../../cacerts/localgitops-ca.pem"
}
provider "time" {}

