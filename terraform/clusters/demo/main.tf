# Backend configuration
terraform {
  backend "azurerm" {
    resource_group_name  = "LightHosting"
    storage_account_name = "lighthosting"
    container_name       = "tfstate"
    key                  = "demo.terraform.tfstate"
  }
}

# Provision servers
module "provider" {
  source = "../../modules/provider/hcloud"

  hcloud_token    = "${var.hcloud_token}"
  
  cluster_name    = "${var.cluster_name}"
  cluster_domain  = "${var.cluster_domain}"
  servers         = "${var.servers}"

  ssh_public_key        = "${var.ssh_public_key}"
  ssh_public_key_name   = "${var.ssh_public_key_name}"
}