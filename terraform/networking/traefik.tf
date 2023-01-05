# Traefik IngressRoute ========================================================
# To prevent abuse of EncryptNow and avoid the horrible 1min-long certs of the
# Traefik Default certificates, set up a Traefik IngressRoute with one's own
# cert.
# This should be started 3min after the clsuter item due to the time it takes
# the Traefik load balancer to spin up with its custom definitions.
# =============================================================================

# Wildcard certificate ========================================================
resource "kubernetes_secret" "localgitops-wildcard-tls" {
  metadata {
    name = "ca-crt"
    namespace = "kube-system"
  }
  type = "kubernetes.io/tls"
  data = {
    "tls.crt" = "${file("${path.module}/../certs/${var.domain}.pem")}"
    "tls.key" = "${file("${path.module}/../certs/${var.domain}.key")}"
  }
}

