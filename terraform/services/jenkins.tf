locals {
  jenkins_namespace = "jenkins"
  jenkins_cr_name = "jenkins-cr"
  jenkins_crb_name = "jenkins-crb"
  jenkins_in_name = "jenkins-in"
  jenkins_pv_name = "jenkins-pv"
  jenkins_pvc_name = "jenkins-pvc"
  jenkins_sa_name = "jenkins-sa"
  jenkins_sc_name = "jenkins-sc"
  jenkins_sv_name = "jenkins"
  jenkins_binding_mode = "WaitForFirstConsumer"
  jenkins_reclaim_policy = "Delete"
  jenkins_access_mode = "ReadWriteOnce"
}

resource "kubernetes_namespace" "jenkins" {
  metadata {
    name = local.jenkins_namespace
  }
}

# Service account, cluster roles and bindings ====================

resource "kubernetes_service_account" "jenkins-sa" {
  metadata {
    name = local.jenkins_sa_name
    namespace = kubernetes_namespace.jenkins.id
  }
}

resource "kubernetes_cluster_role" "jenkins-cr" {
  metadata {
    name = local.jenkins_cr_name
    annotations = {
     "rbac.authorization.kubernetes.io/autoupdate" = "true"
    }
    labels = {
      "kubernetes.io/bootstrapping" = "rbac-defaults"
    }
  }
  rule {
    api_groups = ["*"]
    resources = [
      "statefulsets", "services", "replicationcontrollers", "replicasets",
      "podtemplates", "podsecuritypolicies", "pods", "pods/log", "pods/exec",
      "podpreset", "poddisruptionbudget", "persistentvolumes",
      "persistentvolumeclaims", "jobs", "endpoints", "deployments",
      "deployments/scale", "daemonsets", "cronjobs", "configmaps",
      "namespaces", "events", "secrets"
    ]
    verbs = ["create", "get", "watch", "delete", "list", "patch", "update"]
  }
  rule {
    api_groups = [""]
    resources = ["nodes"]
    verbs = ["get", "watch", "list", "update"]
  }
}

resource "kubernetes_cluster_role_binding" "jenkins-crb" {
  metadata {
    annotations = {
      "rbac.authorization.kubernetes.io/autoupdate" = "true"
    }
    labels = {
      "kubernetes.io/bootstrapping" = "rbac-defaults"
    }
    name = local.jenkins_crb_name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "ClusterRole"
    name = local.jenkins_cr_name
  }
  subject {
    api_group = "rbac.authorization.k8s.io"
    kind = "Group"
    name = "system:serviceaccounts:${local.jenkins_sa_name}"
    namespace = kubernetes_namespace.jenkins.id
  }
}

# Storage ====================================================================

resource "kubernetes_storage_class" "jenkins-sc" {
  metadata {
   name = local.jenkins_sc_name
  }
  storage_provisioner = "kubernetes.io/no-provisioner"
  volume_binding_mode = local.jenkins_binding_mode
}

resource "kubernetes_persistent_volume" "jenkins-pv" {
  metadata {
    name = local.jenkins_pv_name
    labels = {
      "type" = "local"
    }
  }
  spec {
    storage_class_name = local.jenkins_sc_name
    access_modes = [local.jenkins_access_mode]
    capacity = {
      storage = var.jenkins_storage
    }
    persistent_volume_reclaim_policy = local.reclaim_policy
    persistent_volume_source {
      host_path {
        path = "/tmp/pv1"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "jenkins-pvc" {
  metadata {
    name = local.jenkins_pvc_name
    namespace = kubernetes_namespace.jenkins.id
  }
  spec {
    storage_class_name = local.jenkins_sc_name
    access_modes = [local.jenkins_access_mode]
    resources {
      requests = {
        storage = var.jenkins_storage
      }
    }
  }
}

# Service and Ingress ======================================

resource "kubernetes_service" "jenkins-sv" {
  metadata {
    name = local.jenkins_sv_name
    namespace = kubernetes_namespace.jenkins.id
    annotations = {
      "prometheus.io/scrape" = "true"
      "prometheus.io/path" = "/"
      "prometheus.io/port" = "8080"
    }
  }
  spec {
    selector = {
      app = "jenkins-server"
    }
    type = "ClusterIP"
    port {
      port = 8080
      target_port = 8080
    }
  }
}

# Jenkins Ingress ==============================================================
resource "kubernetes_secret" "jenkins-tls" {
  metadata {
    name = "jenkins-tls"
    namespace = kubernetes_namespace.jenkins.id
  }
  type = "kubernetes.io/tls"
  data = {
    "tls.crt" = "${file("${path.module}/../certs/${var.domain}.pem")}"
    "tls.key" = "${file("${path.module}/../certs/${var.domain}.key")}"
  }
}

resource "kubernetes_ingress_v1" "jenkins-ingress-v1" {
  metadata {
    name       = "jenkins-ingress-v1"
    namespace  = kubernetes_namespace.jenkins.id
  }
  spec {
    default_backend {
      service {
        name = "jenkins"
        port {
          number = 8080
        }
      }
    }
    rule {
      http {
        path {
          backend {
            service {
              name = "jenkins"
              port {
                number = 8080
              }
            }
          }
          path = "/"
        }
      }
    }
    tls {
      secret_name = "jenkins-tls"
    }
  }
}

## Jenkins! ================================

resource "kubernetes_deployment" "jenkins" {
  metadata {
    name = "jenkins"
    namespace = kubernetes_namespace.jenkins.id
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        "app" = "jenkins-server"
      }
    }
    template {
      metadata {
        labels = {
          "app" = "jenkins-server"
        }
      }
      spec {
        security_context {
          fs_group = 1000
          run_as_user = 1000
        }
        service_account_name = local.jenkins_sa_name
        container {
          name = "jenkins"
          image = "jenkins/jenkins:lts"
          env {
            name = "JAVA_OPTS"
            value = "-Djenkins.install.runSetupWizard=false"
          }
          env {
            name = "CASC_JENKINS_CONFIG"
            value = "/var/jenkins_home/casc.yaml"
          }
          env {
            name = "JENKINS_ADMIN_ID"
            value = var.jenkins_admin_id
          }
          env {
            name = "JENKINS_ADMIN_PASSWORD"
            value = var.jenkins_admin_password
          }
          resources {
            limits = {
              memory = "2Gi"
              cpu = "1000m"
            }
            requests = {
              memory = "500Mi"
              cpu = "500m"
            }
          }
          port {
            name = "httpport"
            container_port = 8080
          }
          port {
            name = "jnlpport"
            container_port = 50000
          }
          liveness_probe {
            http_get {
              path = "/login"
              port = 8080
            }
            initial_delay_seconds = 90
            period_seconds = 10
            timeout_seconds = 5
            failure_threshold = 5
          }
          readiness_probe {
            http_get {
              path = "/login"
              port = 8080
            }
            initial_delay_seconds = 60
            period_seconds = 10
            timeout_seconds = 5
            failure_threshold = 5
          }
          volume_mount {
            name = "jenkins-data"
            mount_path = "/var/jenkins_home"
          }
        }
        volume {
          name = "jenkins-data"
          persistent_volume_claim {
            claim_name = local.jenkins_pvc_name
          }
        }
      }
    }
  }
}
