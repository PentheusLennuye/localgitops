resource "kubernetes_deployment" "multitool" {
  metadata {
    name = "multitool"
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        "app" = "multitool"
      }
    }
    template {
      metadata {
        labels = {
          "app" = "multitool"
        }
      }
      spec {
        container {
          name = "multitool"
          image = "wbitt/network-multitool"
          volume_mount {
            name = "cacert"
            mount_path = "/usr/local/share/ca-certificates/LocalGitOps.crt"
            sub_path = "ca.crt"
          }
        }
        volume {
          name = "cacert"
          config_map {
	    name = kubernetes_config_map.ca_crt.metadata[0].name
          }
        }
      }
    }
  }
}
resource "kubernetes_deployment" "docker" {
  metadata {
    name = "docker"
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        "app" = "docker"
      }
    }
    template {
      metadata {
        labels = {
          "app" = "docker"
        }
      }
      spec {
        container {
          name = "docker"
          image = "docker:20.10.22-dind"
          command = [ "sh", "-c", "tail -f /dev/null"]
          volume_mount {
            name = "cacert"
            mount_path = "/usr/local/share/ca-certificates/LocalGitOps.crt"
            sub_path = "ca.crt"
          }
          env {
            name = "DOCKER_TLS_CERTDIR"
            value = "/certs"
          }
        }
        volume {
          name = "cacert"
          config_map {
	    name = kubernetes_config_map.ca_crt.metadata[0].name
          }
        }
      }
    }
  }
}

