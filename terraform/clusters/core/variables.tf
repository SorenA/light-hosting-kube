# Cluster configuration

variable "cluster_name" {}
variable "cluster_domain" {}
variable "cluster_enable_floating_ip" {}
variable "servers" {}

# SSH configuration

variable "ssh_private_key" {}
variable "ssh_public_key" {}
variable "ssh_public_key_name" {
  default = "default"
}

# Provider configuration - Hetzner

variable "hcloud_token" {}

# Provider configuration - Cloudflare

variable "cloudflare_email" {}
variable "cloudflare_api_key" {}
variable "cloudflare_zone_id" {}

# Provider configuration - Rancher2

variable "rancher_default_password" {}