locals {
  openldap_namespace = "openldap"
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

# Storage plain won't work with local files. Persistence will be local to the
# cluster. No cluster, no persistence.

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
# ldapsearch -x -W -Z -b "dc=gitops,dc=local" -D "cn=bind_ldap,ou=users,dc=gitops,dc=local" -H ldap://openldap.gitops.local cn
  set {
    name  = "users"
    value = "bind_ldap"
  }
  set {
    name  = "userPasswords"
    value = "${var.openldap_bind_password}}"
  }
  set {
    name  = "group"
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
}
