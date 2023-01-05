terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
      version = "2.7.1"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.15.0"
    }
  }
}

provider "kubernetes" {
  config_path = "../kubeconfig"
  config_context = "k3d-localgitops"
}

provider "helm" {
  kubernetes {
    config_path = "../kubeconfig"
    config_context = "k3d-localgitops"
  }
}
