# Cluster configuration

variable "cluster_name" {}
variable "cluster_domain" {}
variable "cluster_enable_floating_ip" {}
variable "servers" {}

# SSH configuration

variable "ssh_public_key" {}
variable "ssh_public_key_name" {
  default = "default"
}

# Provider configuration - Hetzner

variable "hcloud_token" {}
variable "hcloud_manage_ssh_key" {}
variable "hcloud_location" {
  default = "nbg1"
}
variable "hcloud_image" {
  default = "ubuntu-18.04"
}
variable "hcloud_backups" {
  default = false
}
variable "hcloud_network_ip_range" {
  default = "10.0.0.0/8"
}
variable "hcloud_network_subnet_ip_range" {
  default = "10.0.0.0/16"
}
variable "hcloud_network_zone" {
  default = "eu-central"
}

# Provider configuration - Rancher
variable "rancher_agent_node_command" {
  default = ""
}