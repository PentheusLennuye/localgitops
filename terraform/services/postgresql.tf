locals {
  postgresql_namespace = "postgresql"
  postgresql_sc_name = "postgresql-sc"
  postgresql_pv_name = "postgresql-pv"
  postgresql_pvc_name = "postgresql-pvc"
  postgresql_binding_mode = "Immediate"
  postgresql_reclaim_policy = "Delete"
  postgresql_access_mode = "ReadWriteOnce"
}

# Namespace ==================================================================

resource "kubernetes_namespace" "postgresql" {
  metadata {
    name = local.postgresql_namespace
  }
}

resource "kubernetes_secret" "postgresql-certs" {
  metadata {
    name = "postgresql-certs"
    namespace = kubernetes_namespace.postgresql.id
  }
  data = {
    ca_crt = "${file("${path.module}/../../cacerts/localgitops-ca.pem")}"
    host_crt = "${file("${path.module}/../certs/star_postgresql_svc_cluster_local.pem")}"
    host_key = "${file("${path.module}/../certs/star_postgresql_svc_cluster_local.key")}"
  }
}

# Storage ====================================================================

resource "kubernetes_storage_class" "postgresql-sc" {
  metadata {
   name = local.postgresql_sc_name
  }
  storage_provisioner = "kubernetes.io/no-provisioner"
  volume_binding_mode = local.postgresql_binding_mode
}

resource "kubernetes_persistent_volume" "postgresql-pv" {
  metadata {
    name = local.postgresql_pv_name
    labels = {
      "type" = "local"
    }
  }
  spec {
    storage_class_name = local.postgresql_sc_name
    access_modes = [local.postgresql_access_mode]
    capacity = {
      storage = var.postgresql_storage
    }
    persistent_volume_reclaim_policy = local.postgresql_reclaim_policy
    persistent_volume_source {
      host_path {
        path = "/tmp/pv3"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "postgresql-pvc" {
  metadata {
    name = local.postgresql_pvc_name
    namespace = kubernetes_namespace.postgresql.id
  }
  spec {
    storage_class_name = local.postgresql_sc_name
    access_modes = [local.postgresql_access_mode]
    resources {
      requests = {
        storage = var.postgresql_storage
      }
    }
  }
}

resource "helm_release" "postgresql" {
  name = "postgresql"
  namespace = kubernetes_namespace.postgresql.id
  depends_on = [
    kubernetes_persistent_volume_claim.postgresql-pvc
  ]
  repository = "https://charts.bitnami.com/bitnami"
  chart = "postgresql"
  version = var.postgresql_helm_version
  values = [
    "${file("helm_values/postgresql_helm_values.yaml")}"
  ]
  set {
    name = "primary.persistence.existingClaim"
    value = local.postgresql_pvc_name
  }
  set {
    name = "global.postgresql.auth.postgresPassword"
    value = var.postgresql_password
  }
}
