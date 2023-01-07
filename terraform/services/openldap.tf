locals {
  openldap_namespace = "openldap"
  openldap_storageclass_name = "openldap-sc"
  openldap_reclaim_policy = "Retain"
  openldap_access_mode = "ReadWriteOnce"
}

# ========== Namespace ======================================

resource "kubernetes_namespace" "openldap" {
  metadata {
    name = local.openldap_namespace
  }
}

# ========== Storage Classes =============================

resource "kubernetes_storage_class" "openldap-sc" {
  metadata {
    name = local.openldap_storageclass_name
  }
  storage_provisioner = "Local"
  reclaim_policy = local.openldap_reclaim_policy
  volume_binding_mode = "Immediate"
}
resource "kubernetes_persistent_volume" "openldap-pv" {
  metadata {
    name = "openldap-pv"
  }
  spec {
    storage_class_name = local.openldap_storageclass_name
    access_modes = [local.openldap_access_mode]
    capacity = {
      storage = var.openldap_storage
    }
    persistent_volume_reclaim_policy = local.openldap_reclaim_policy
    persistent_volume_source {
      host_path {
        path = "/tmp/${var.openldap_pv_vol}"
      }
    }
  }
}
resource "helm_release" "openldap" {
  name = "openldap"
  depends_on = [
    kubernetes_persistent_volume.openldap-pv
  ]
  namespace = kubernetes_namespace.openldap.id
  repository = "https://jp-gouin.github.io/helm-openldap"
  chart = "openldap-stack-ha"
  values = [
    "${file("helm_values/openldap_helm_values.yaml")}"
  ]
  version = var.openldap_helm_version
  set {
    name = "global.ldapDomain"
    value = var.domain
  }
}
