# DNS rewrite external domain to internal domain ==============================
resource "kubernetes_config_map" "rewrites" {
  metadata {
    name = "coredns-custom"
    namespace = "kube-system"
  }
  data = {
    "gitops.local.server" = <<-EOREWRITE
      gitops.local {
        rewrite name ${var.k8s_fqdn} kubernetes.default.svc.cluster.local
        rewrite name ${var.dex_fqdn} dex.dex.svc.cluster.local
        rewrite name ${var.jenkins_fqdn} jenkins.jenkins.svc.cluster.local
        rewrite name ${var.openldap_fqdn} openldap.openldap.svc.cluster.local
        rewrite name ${var.vault_fqdn} vault.vault.svc.cluster.local
        rewrite name ${var.harbor_fqdn} harbor-core.harbor.svc.cluster.local
        forward . 127.0.0.1
    }
    EOREWRITE
  }
}

