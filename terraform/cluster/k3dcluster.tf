resource "k3d_cluster" "localgitops" {
  name = "localgitops"
  servers = 1
  agents = 2

  kube_api {
    host = var.cluster_fqdn
    host_ip = "127.0.0.1"
    host_port = 6445
  }

  image = "rancher/k3s:${var.k3dver}"
  network = "k3d-localgitops"

  port {
    host_port = 443
    container_port = 443
    node_filters = [ "loadbalancer" ]
  }

  port {
    host_port = 9000
    container_port = 9000
    node_filters = [ "loadbalancer" ]
  }

  volume {
    source = var.pv1
    destination = "/tmp/pv1"
  }
  volume {
    source = var.pv2
    destination = "/tmp/pv2"
  }
  volume {
    source = var.pv3
    destination = "/tmp/pv3"
  }
  volume {
    source = var.pv4
    destination = "/tmp/pv4"
  }
  volume {
    source = var.pv5
    destination = "/tmp/pv5"
  }
  volume {
    source = var.pv6
    destination = "/tmp/pv6"
  }

  k3d {
    disable_load_balancer = "false"
  }

  k3s {
    extra_args {
      arg = "--disable=traefik"
      node_filters = [ "server:*" ]
    }
  }

  kubeconfig {
    update_default_kubeconfig = true
    switch_current_context = true
  }

}

