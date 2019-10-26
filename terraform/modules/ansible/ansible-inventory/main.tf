provider "local" {
   version = "~> 1.4"
}

# Create Ansible Inventory file
resource "local_file" "default" {
    content     = <<EOF
[nodes]
${join("\n", values(var.server_ips))}
    EOF
    filename = "${path.root}/../../../ansible/inventories/${var.cluster_name}"
}
