# Backend configuration
terraform {
  backend "azurerm" { # Change these as needed
    resource_group_name  = "LightHosting" # Name of Azure Resource Group
    storage_account_name = "lighthosting" # Name of Azure Storage Account
    container_name       = "tfstate" # Name of container in storage account
    key                  = "default.terraform.tfstate" # Should be unique per cluster!
  }
}

# Provision servers
module "provider" {
  source = "../../modules/provider/hcloud"

  hcloud_token    = "${var.hcloud_token}"
  
  cluster_name    = "${var.cluster_name}"
  cluster_domain  = "${var.cluster_domain}"
  cluster_enable_floating_ip  = "${var.cluster_enable_floating_ip}"
  servers         = "${var.servers}"

  ssh_public_key        = "${var.ssh_public_key}"
  ssh_public_key_name   = "${var.ssh_public_key_name}"
}

# Provision DNS
module "dns" {
  source = "../../modules/dns/cloudflare"

  cloudflare_email    = "${var.cloudflare_email}"
  cloudflare_api_key  = "${var.cloudflare_api_key}"
  cloudflare_zone_id  = "${var.cloudflare_zone_id}"
  
  cluster_domain  = "${var.cluster_domain}"
  cluster_enable_floating_ip  = "${var.cluster_enable_floating_ip}"
  servers         = "${var.servers}"

  server_ips      = "${module.provider.server_ips}"
  floating_ip     = "${module.provider.floating_ip}"
}

# Ansible Inventory
module "ansible_inventory" {
  source = "../../modules/ansible/ansible-inventory"

  cluster_name    = "${var.cluster_name}"
  server_ips      = "${module.provider.server_ips}"
  floating_ip     = "${module.provider.floating_ip}"
}