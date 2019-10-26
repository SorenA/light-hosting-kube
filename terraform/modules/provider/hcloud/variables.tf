# Cluster configuration

variable "cluster_name" {}
variable "cluster_domain" {}
variable "servers" {}

# SSH configuration

variable "ssh_public_key" {}
variable "ssh_public_key_name" {
  default = "default"
}

# Provider configuration - Hetzner

variable "hcloud_token" {}
variable "hcloud_location" {
  default = "nbg1"
}
variable "hcloud_image" {
  default = "ubuntu-18.04"
}
variable "hcloud_backups" {
  default = false
}