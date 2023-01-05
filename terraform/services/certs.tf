resource "kubernetes_config_map" "ca_crt" {
  metadata {
    name = "ca-crt"
  }
  data = {
    "ca.crt" = "${file("${path.module}/../../cacerts/localgitops-ca.pem")}"
  }
}
resource "kubernetes_secret" "localdevelopment-tls" {
  metadata {
    name = "traefik-tls"
    namespace = "kube-system"
  }
  type = "kubernetes.io/tls"
  data = {
    "tls.crt" = "${file("${path.module}/../certs/${var.domain}.pem")}"
    "tls.key" = "${file("${path.module}/../certs/${var.domain}.key")}"
  }
}
