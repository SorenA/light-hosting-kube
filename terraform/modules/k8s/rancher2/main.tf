locals {
  //rancher_urls = {for key, value in var.servers : key => "${value.name}.${var.cluster_domain} if value.install_rancher"}
  rancher_urls = [for key, value in var.servers: "${value.name}.${var.cluster_domain}" if value.install_rancher]
}

provider "rancher2" {
  version = "~> 1.6"
  
  api_url   = "https://${local.rancher_urls.0}"
  bootstrap = true
}

resource "rancher2_bootstrap" "default" {
  password = "${var.rancher_default_password}"
  telemetry = false
}