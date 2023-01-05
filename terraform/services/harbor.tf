locals {
  harbor_namespace = "harbor"
  harbor_sc_name = "harbor-sc"
  harbor_pv_name = "harbor-pv"
  harbor_pvc_name = "harbor-pvc"
  harbor_binding_mode = "WaitForFirstConsumer"
  harbor_reclaim_policy = "Retain"
  harbor_access_mode = "ReadWriteOnce"
  harbors = ["chartmuseum", "core", "jobservice", "portal", "registry", "trivy"]
}

# Namespace ==================================================================

resource "kubernetes_namespace" "harbor" {
  metadata {
    name = local.harbor_namespace
  }
}

# Certs ===========================================================
resource "kubernetes_secret" "harbor-tls" {
  count = length(local.harbors)
  metadata {
    name = "harbor-${local.harbors[count.index]}-tls"
    namespace = kubernetes_namespace.harbor.id
  }
  data = {
    "ca.crt" = "${file("${path.module}/../../cacerts/localgitops-ca.pem")}"
    "tls.crt" = "${file("${path.module}/../certs/harbor_${local.harbors[count.index]}_harbor_svc_cluster_local.pem")}"
    "tls.key" = "${file("${path.module}/../certs/harbor_${local.harbors[count.index]}_harbor_svc_cluster_local.key")}"
  }
}

# Storage ====================================================================

resource "kubernetes_storage_class" "harbor-registry-sc" {
  metadata {
   name = "${local.harbor_sc_name}-registry"
  }
  storage_provisioner = "kubernetes.io/no-provisioner"
  volume_binding_mode = local.harbor_binding_mode
}
resource "kubernetes_storage_class" "harbor-chartmuseum-sc" {
  metadata {
   name = "${local.harbor_sc_name}-chartmuseum"
  }
  storage_provisioner = "kubernetes.io/no-provisioner"
  volume_binding_mode = local.harbor_binding_mode
}
resource "kubernetes_storage_class" "harbor-jobservice-sc" {
  metadata {
   name = "${local.harbor_sc_name}-jobservice"
  }
  storage_provisioner = "kubernetes.io/no-provisioner"
  volume_binding_mode = local.harbor_binding_mode
}

## Persistent Volumes --------------------

resource "kubernetes_persistent_volume" "harbor-registry-pv" {
  metadata {
    name = "${local.harbor_pv_name}-4"
    labels = {
      "type" = "local"
    }
  }
  spec {
    storage_class_name = "${local.harbor_sc_name}-registry"
    access_modes = [local.harbor_access_mode]
    capacity = {
      storage = var.harbor_storage
    }
    persistent_volume_reclaim_policy = local.harbor_reclaim_policy
    persistent_volume_source {
      host_path {
        path = "/tmp/pv4"
      }
    }
  }
}
resource "kubernetes_persistent_volume" "harbor-chartmuseum-pv" {
  metadata {
    name = "${local.harbor_pv_name}-5"
    labels = {
      "type" = "local"
    }
  }
  spec {
    storage_class_name = "${local.harbor_sc_name}-chartmuseum"
    access_modes = [local.harbor_access_mode]
    capacity = {
      storage = var.harbor_storage
    }
    persistent_volume_reclaim_policy = local.harbor_reclaim_policy
    persistent_volume_source {
      host_path {
        path = "/tmp/pv5"
      }
    }
  }
}
resource "kubernetes_persistent_volume" "harbor-jobservice-pv" {
  metadata {
    name = "${local.harbor_pv_name}-6"
    labels = {
      "type" = "local"
    }
  }
  spec {
    storage_class_name = "${local.harbor_sc_name}-jobservice"
    access_modes = [local.harbor_access_mode]
    capacity = {
      storage = var.harbor_storage
    }
    persistent_volume_reclaim_policy = local.harbor_reclaim_policy
    persistent_volume_source {
      host_path {
        path = "/tmp/pv6"
      }
    }
  }
}

# Harbor Helm ================================================================

resource "helm_release" "harbor" {
  name = "harbor"
  namespace = kubernetes_namespace.harbor.id
  depends_on = [ helm_release.postgresql ]
  repository = "https://helm.goharbor.io"
  chart = "harbor"
  version = var.harbor_helm_version
  values = [
    "${file("helm_values/harbor_helm_values.yaml")}"
  ]
  set {
    name = "persistence.persistentVolumeClaim.registry.storageClass"
    value = "${local.harbor_sc_name}-registry"
  }
  set {
    name = "persistence.persistentVolumeClaim.registry.accessMode"
    value = local.harbor_access_mode
  }
  set {
    name = "persistence.persistentVolumeClaim.chartmuseum.storageClass"
    value = "${local.harbor_sc_name}-chartmuseum"
  }
  set {
    name = "persistence.persistentVolumeClaim.chartmuseum.accessMode"
    value = local.harbor_access_mode
  }
  set {
    name = "persistence.persistentVolumeClaim.jobservice.storageClass"
    value = "${local.harbor_sc_name}-jobservice"
  }
  set {
    name = "persistence.persistentVolumeClaim.jobservice.accessMode"
    value = local.harbor_access_mode
  }
  set {
    name  = "database.external.username"
    value = "postgres"
  }
  set {
    name  = "database.external.password"
    value = var.postgresql_password
  }
  set {
    name  = "harborAdminPassword"
    value = var.harbor_admin_password
  }
  set {
    name  = "externalURL"
    value = "https://${var.harbor_fqdn}"
  }
  set {
    name  = "expose.ingress.hosts.core"
    value = "${var.harbor_fqdn}"
  }
  set {
    name  = "expose.ingress.hosts.notary"
    value = "${var.harbor_notary_fqdn}"
  }
}
