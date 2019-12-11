provider "local" {
   version = "~> 1.4"
}

locals {
  rancher_domain_names = [for key, value in var.servers: "${value.name}.${var.cluster_domain}" if value.install_rancher]
  rancher_ips = [for key, value in var.servers: var.server_ips[key] if value.install_rancher]
}

# Create Ansible Inventory file
resource "local_file" "ansible_inventory" {
    content     = <<EOF
${join("\n", values(var.server_ips))}
    EOF
    filename = "${path.root}/../../../ansible/clusters/${var.cluster_name}/inventory"
}

# Create Ansible vars.yml file
resource "local_file" "ansible_vars" {
    content     = <<EOF
---
floating_ip: ${var.floating_ip}
private_network: ${var.private_network}
cluster_name: ${var.cluster_name}
cluster_domain: ${var.cluster_domain}
${length(local.rancher_domain_names) > 0 ? "rancher_domain_name: ${local.rancher_domain_names.0}" : ""}
${length(local.rancher_ips) > 0 ? "rancher_ip_address: ${local.rancher_ips.0}" : ""}
    EOF
    filename = "${path.root}/../../../ansible/clusters/${var.cluster_name}/vars.yml"
}
