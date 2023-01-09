locals {
  openldap_namespace = "openldap"
  openldap_storageclass_name = "openldap-sc"
  openldap_pvc_name = "openldap-pvc"
  openldap_reclaim_policy = "Retain"
  openldap_access_mode = "ReadWriteOnce"
}

# ========== Namespace ======================================

resource "kubernetes_namespace" "openldap" {
  metadata {
    name = local.openldap_namespace
  }
}

# ========== TLS ======================================

resource "kubernetes_secret" "openldap-tls" {
  metadata {
    name = "openldap-tls"
    namespace = kubernetes_namespace.openldap.id
  }
  type = "kubernetes.io/tls"
  data = {
    "ca.crt" = "${file("${path.module}/../../cacerts/localgitops-ca.pem")}"
    "tls.crt" = "${file("${path.module}/../certs/${var.domain}.pem")}"
    "tls.key" = "${file("${path.module}/../certs/${var.domain}.key")}"
  }
}

# ========== Storage =========================================================

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

#resource "kubernetes_persistent_volume_claim" "openldap-pvc" {
#  metadata {
#    name = local.openldap_pvc_name
#    namespace = kubernetes_namespace.openldap.id
#  }
#  spec {
#    storage_class_name = local.openldap_storageclass_name
#    access_modes = [local.openldap_access_mode]
#    resources {
#      requests = {
#        storage = var.openldap_storage
#      }
#    }
#  }
#}
#
# ======== HELM RELEASE ======================================================

resource "helm_release" "openldap" {
  name = "openldap"
  namespace = kubernetes_namespace.openldap.id
  repository = "https://jp-gouin.github.io/helm-openldap"
  chart = "openldap-stack-ha"
  values = [
    "${file("helm_values/openldap_helm_values.yaml")}"
  ]
  version = var.openldap_helm_version
# ldapsearch example: ldapsearch -H ldaps://openldap.gitops.local:636 -x -W -D "cn=admin,dc=gitops,dc=local" cn
# ldapsearch example: ldapsearch -H ldap://openldap.gitops.local -x -Z -W -D "cn=admin,dc=gitops,dc=local" cn
# No TLS:
# ldapsearch example: ldapsearch -H ldap://openldap.gitops.local -x -W -D "cn=admin,dc=gitops,dc=local" cn
  set {
    name  = "env.LDAP_USERS"
    value = "bind_ldap"
  }
  set {
    name  = "env.LDAP_PASSWORDS"
    value = "Youpiedoopiedoopie"
  }
  set {
    name  = "env.LDAP_GROUP"
    value = "users"
  }
  set {
    name = "global.ldapDomain"
    value = var.domain
  }
  set {
    name = "global.adminPassword"
    value = var.openldap_admin_password
  }
  set {
    name = "global.configPassword"
    value = var.openldap_admin_password
  }
  set {
    name = "customTLS.secret"
    value = "openldap-tls"
  }
  set {
    name = "persistence.storageClass"
    value = local.openldap_storageclass_name
  }
  set {
    name = "persistence.accessModes[0]"
    value = local.openldap_access_mode
  }
  set {
    name = "persistence.size"
    value = var.openldap_storage
  }
}
