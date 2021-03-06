# Cluster configuration

variable "cluster_name" {}

# Provider configuration - Rancher2 Agent

variable "rancher_api_url" {}
variable "rancher_bearer_token" {}
variable "rancher_kubernetes_version" {
  default = "v1.18.8-rancher1-1"
}