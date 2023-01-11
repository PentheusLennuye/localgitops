locals {
  dex_namespace = "dex"
}

# ========== Namespace ======================================

resource "kubernetes_namespace" "dex" {
  metadata {
    name = local.dex_namespace
  }
}

# ========== TLS =============================
resource "kubernetes_secret" "dex-tls" {
  metadata {
    name = "dex-tls"
    namespace = kubernetes_namespace.dex.id
  }
  type = "kubernetes.io/tls"
  data = {
    "tls.crt" = "${file("${path.module}/../certs/${var.domain}.pem")}"
    "tls.key" = "${file("${path.module}/../certs/${var.domain}.key")}"
  }
}

resource "kubernetes_secret" "dex-tls-internal" {
  metadata {
    name = "dex-tls-internal"
    namespace = kubernetes_namespace.dex.id
  }
  type = "kubernetes.io/tls"
  data = {
    "ca.crt" = "${file("${path.module}/../../cacerts/localgitops-ca.pem")}"
    "tls.crt" = "${file("${path.module}/../certs/star_dex_svc_cluster_local.pem")}"
    "tls.key" = "${file("${path.module}/../certs/star_dex_svc_cluster_local.key")}"
  }
}

# ========== Helm =============================

resource "helm_release" "dex" {
  name = "dex"
  namespace = kubernetes_namespace.dex.id
 repository = "https://charts.dexidp.io"
 chart = "dex"
 version = var.dex_helm_version
 values = [ "${file("helm_values/dex_helm_values.yaml")}" ]
 set {
   name  = "config.issuer"
   value = "https://${var.dex_fqdn}"
 }
 set {
   name  = "config.connectors[0].config.bindPW"
   value = "${var.openldap_bind_password}"
 }
 set {
   name  = "config.connectors[0].config.host"
   value = "${var.openldap_fqdn}:636"
 }
 set {
   name  = "config.staticClients[0].redirectURIs[0]"
   value = "https://${var.jenkins_fqdn}/securityRealm/finishLogin"
 }
 set {
   name  = "config.staticClients[0].secret"
   value = "${var.oidc_client_secret}"
 }
 set {
   name  = "config.staticClients[1].redirectURIs[0]"
   value = "https://${var.vault_fqdn}/ui/vault/auth/oidc/oidc/callback"
 }
 # Believe it or not, this is what it is supposed to be
 set {
   name  = "config.staticClients[1].redirectURIs[1]"
   value = "http://localhost:8250/oidc/callback"
 }
 set {
   name  = "config.staticClients[1].secret"
   value = "${var.oidc_client_secret}"
 }
 set {
   name  = "config.staticClients[2].redirectURIs[0]"
   value = "https://${var.harbor_fqdn}/c/oidc/callback"
 }
 set {
   name  = "config.staticClients[2].secret"
   value = "${var.oidc_client_secret}"
 }
 set {
   name  = "ingress.hosts[0].host"
   value = "${var.dex_fqdn}"
 }
 set {
   name  = "ingress.hosts[0].paths[0].path"
   value = "/"
 }
 set {
   name  = "ingress.hosts[0].paths[0].pathType"
   value = "Prefix"
 }
 set {
   name  = "ingress.tls[0].secretName"
   value = "dex-tls"
 }
 set {
   name  = "ingress.tls[0].hosts[0]"
   value = "${var.dex_fqdn}"
 }
}
