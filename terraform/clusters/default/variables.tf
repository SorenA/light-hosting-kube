# Cluster configuration

variable "cluster_name" {}
variable "cluster_domain" {}
variable "servers" {}

# SSH configuration

variable "ssh_private_key" {}
variable "ssh_public_key" {}
variable "ssh_public_key_name" {
  default = "default"
}

# Provider configuration - Hetzner

variable "hcloud_token" {}