provider "local" {
   version = "~> 1.4"
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
    EOF
    filename = "${path.root}/../../../ansible/clusters/${var.cluster_name}/vars.yml"
}
