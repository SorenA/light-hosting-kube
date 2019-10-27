provider "rancher2" {
  version = "~> 1.6"
  
  api_url     = "${var.rancher_api_url}"
  token_key   = "${var.rancher_bearer_token}"
}

# Configure cluster
resource "rancher2_cluster" "default" {
  name = "${var.cluster_name}"

  cluster_auth_endpoint {
    enabled = true
  }
  enable_cluster_alerting = true
  enable_cluster_monitoring = true

  rke_config {
    network {
      plugin = "canal"
      canal_network_provider {
        iface = "eth0"
      }
    }

    ingress {
      provider = "none"
    }

    services {
      etcd {
        backup_config {
          enabled        = "true"
          interval_hours = 6
          retention      = 28
        }
      }

      kubelet {
        extra_args = {
          cloud-provider = "external"
        }
      }
    }
  }

  cluster_monitoring_input {
    answers = {
      "exporter-kubelets.https"                   = true
      "exporter-node.enabled"                     = true
      "exporter-node.ports.metrics.port"          = 9796
      "exporter-node.resources.limits.cpu"        = "200m"
      "exporter-node.resources.limits.memory"     = "200Mi"
      "grafana.persistence.enabled"               = false
      "operator.resources.limits.memory"          = "500Mi"
      "prometheus.persistence.enabled"            = false
      "prometheus.persistent.useReleaseName"      = "true"
      "prometheus.resources.core.limits.cpu"      = "1000m",
      "prometheus.resources.core.limits.memory"   = "1500Mi"
      "prometheus.resources.core.requests.cpu"    = "750m"
      "prometheus.resources.core.requests.memory" = "750Mi"
      "prometheus.retention"                      = "12h"
    }
  }
}