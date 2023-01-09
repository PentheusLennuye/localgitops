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

# =========== Ingress ==========================

# We won't need ingress. Dex is used internally, and we aren't zero-trust yet.

# ========== Helm =============================

#resource "helm_release" "dex" {
#  name = "dex"
#  namespace = kubernetes_namespace.dex.id
# repository = "https://wiremind.github.io/wiremind-helm-charts"
# chart = "dex"
# version = var.dex_helm_version
# values = [ "${file("helm_values/dex_helm_values.yaml")}" ]
#  set {
#    name  = "config.issuer"
#    value = "http:{{ var.dex_fqdn}}"
# }
#}
