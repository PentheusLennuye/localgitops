locals {
  vault_namespace = "vault"
  storageclass_name = "vault-sc"
  reclaim_policy = "Retain"
  access_mode = "ReadWriteOnce"
}

# ========== Namespace ======================================

resource "kubernetes_namespace" "vault" {
  metadata {
    name = local.vault_namespace
  }
}

# ========== Storage Classes =============================

resource "kubernetes_storage_class" "vault-sc" {
  metadata {
    name = local.storageclass_name
  }
  storage_provisioner = "Local"
  reclaim_policy = local.reclaim_policy
  volume_binding_mode = "Immediate"
}
resource "kubernetes_persistent_volume" "vault-pv" {
  metadata {
    name = "vault-pv"
  }
  spec {
    storage_class_name = local.storageclass_name
    access_modes = [local.access_mode]
    capacity = {
      storage = var.vault_storage
    }
    persistent_volume_reclaim_policy = local.reclaim_policy
    persistent_volume_source {
      host_path {
        path = "/tmp/pv2"
      }
    }
  }
}
resource "helm_release" "vault" {
  name = "vault"
  depends_on = [
    kubernetes_persistent_volume.vault-pv
  ]
  namespace = kubernetes_namespace.vault.id
  repository = "https://helm.releases.hashicorp.com"
  chart = "vault"
  values = [
    "${file("helm_values/vault_helm_values.yaml")}"
  ]
  version = var.vault_helm_version
  set {
    name = "server.dataStorage.storageClass"
    value = local.storageclass_name
  }
  set {
    name = "server.dataStorage.size"
    value = var.vault_storage
  }
  set {
    name = "server.dataStorage.accessMode"
    value = local.access_mode
  }
  set {
    name = "server.service.nodePort"
    value = var.vault_nodeport
  }
  set {
    name = "server.ingress.hosts[0].host"
    value = "${var.vault_fqdn}"
  }
  set {
    name = "server.ingress.hosts[0].paths[0]"
    value = "\"/\""
  }
}
