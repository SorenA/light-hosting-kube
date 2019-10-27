# Cluster configuration

variable "cluster_domain" {}
variable "cluster_enable_floating_ip" {}
variable "servers" {}
variable "server_ips" {}
variable "floating_ip" {}

# Provider configuration - Cloudflare

variable "cloudflare_email" {}
variable "cloudflare_api_key" {}
variable "cloudflare_zone_id" {}