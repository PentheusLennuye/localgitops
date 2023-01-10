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
   name   = "config.connectors[0].config.bindPW"
   values = "${var.openldap_bind_password}"
 }
 set {
   name   = "config.connectors[0].config.host"
   values = "${var.openldap_fqdn}:636"
 }
 set {
   name   = "config.issuer"
   values = "https://${var.openldap_fqdn}"
 }
 set {
   name   = "config.staticClients[0].redirectURIs[0]"
   values = "https://${var.jenkins_fqdn}/securityRealm/finishLogin"
 }
 set {
   name   = "config.staticClients[0].secret"
   values = "${var.oidc_client_secret}"
 }
 set {
   name   = "config.staticClients[1].redirectURIs[1]"
   values = "https://${var.vault_fqdn}/callback"
 }
 set {
   name   = "config.staticClients[1].secret"
   values = "${var.oidc_client_secret}"
 }
 set {
   name   = "config.staticClients[2].redirectURIs[1]"
   values = "https://${var.harbor_fqdn}/c/oidc/callback"
 }
 set {
   name   = "config.staticClients[2].secret"
   values = "${var.oidc_client_secret}"
 }
 set {
   name   = "ingress.hosts[0].host"
   values = "${var.dex_fqdn"}
 }
 set {
   name   = "ingress.hosts[0].paths[0].path"
   values = "/"
 }
 set {
   name   = "ingress.hosts[0].paths[0].pathType"
   values = "Prefix"
 }
 set {
   name   = "ingress.tls[0].secretName"
   values = "dex-tls"
 }
 set {
   name   = "ingress.tls[0].hosts[0]"
   values = "${var.dex_fqdn}"
 }
}
