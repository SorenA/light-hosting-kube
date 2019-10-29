provider "hcloud" {
  version = "~> 1.14"
  token = "${var.hcloud_token}"
}

# SSH
resource "hcloud_ssh_key" "default" {
  count = "${var.hcloud_manage_ssh_key ? 1 : 0}" # Only if SSH key is managed by Terraform

  name       = "${var.ssh_public_key_name}"
  public_key = "${file(var.ssh_public_key)}"
}

data "hcloud_ssh_key" "default" {
  count = "${var.hcloud_manage_ssh_key ? 0 : 1}" # Only if SSH key is not managed by Terraform

  name       = "${var.ssh_public_key_name}"
}

# Servers
resource "hcloud_server" "node" {
  // for_each with provisioner using self causes Terraform to crash in v0.12.12: https://github.com/hashicorp/terraform/issues/23191
  //for_each = "${var.servers}"
  //name        = "${var.cluster_name}-${each.value.name}"
  //server_type = "${each.value.server_type}"

  // Provision using count instead
  count       = "${length(values(var.servers))}"
  name        = "${var.cluster_name}-${lookup(element(values(var.servers), count.index), "name")}"
  server_type = "${lookup(element(values(var.servers), count.index), "server_type")}"

  image       = "${var.hcloud_image}"
  location    = "${var.hcloud_location}"
  backups     = "${var.hcloud_backups}"
  ssh_keys    = ["${length(hcloud_ssh_key.default) > 0 ? hcloud_ssh_key.default.0.name : length(data.hcloud_ssh_key.default) > 0 ? data.hcloud_ssh_key.default.0.name : ""}"]

  labels = {
    cluster = "${var.cluster_name}"
    domain = "${lookup(element(values(var.servers), count.index), "name")}.${var.cluster_domain}"
  }

  # Wait for server to boot fully
  provisioner "remote-exec" {
    inline = [
      "echo Ready for ansible",
    ]

    connection {
      host        = "${self.ipv4_address}"
    }
  }

  # Run Ansible playbook for provisioning setup
  provisioner "local-exec" {
    command = "cd ${path.root}/../../../ansible/ && ANSIBLE_CONFIG=ansible.cfg ansible-playbook -i '${self.ipv4_address},' --extra-vars 'ansible_user=root ${var.cluster_enable_floating_ip ? "floating_ip=${hcloud_floating_ip.default.0.ip_address}" : ""}' provision.yml"
  }

  # Install Rancher if server is configured so
  provisioner "local-exec" {
    command = "${lookup(element(values(var.servers), count.index), "install_rancher") == true ? "cd ${path.root}/../../../ansible/ && ANSIBLE_CONFIG=ansible.cfg ansible-playbook -i '${self.ipv4_address},' --extra-vars 'rancher_ip_address=${self.ipv4_address} rancher_domain_name=${lookup(element(values(var.servers), count.index), "name")}.${var.cluster_domain}' provision-rancher2.yml" : "sleep 0"}"
  }

  # Install Rancher Agent if server is configured so
  provisioner "remote-exec" {
    inline = [
      "${lookup(element(values(var.servers), count.index), "install_rancher_agent") == true ? "${var.rancher_agent_node_command} --internal-address ${lookup(element(values(var.servers), count.index), "private_ip_address")} --address ${self.ipv4_address} ${lookup(element(values(var.servers), count.index), "rancher_agent_roles")}" : "sleep 0"}",
    ]

    connection {
      host        = "${self.ipv4_address}"
      user        = "deploy"
    }
  }
}

# Floating IP
resource "hcloud_floating_ip" "default" {
  count = "${var.cluster_enable_floating_ip ? 1 : 0}" # Only if floating ip is enabled

  type          = "ipv4"
  description   = "${var.cluster_name}"
  home_location = "${var.hcloud_location}"

  labels = {
    cluster = "${var.cluster_name}"
    domain = "${var.cluster_domain}"
  }
}
resource "hcloud_floating_ip_assignment" "default" {
  count = "${var.cluster_enable_floating_ip ? 1 : 0}" # Only if floating ip is enabled

  floating_ip_id = "${hcloud_floating_ip.default.0.id}"
  server_id = "${hcloud_server.node.0.id}" # Default to first node
}

# Reverse DNS
resource "hcloud_rdns" "node" {
  for_each = "${var.servers}"

  server_id       = "${lookup(hcloud_server.node[each.key], "id")}"
  ip_address      = "${lookup(hcloud_server.node[each.key], "ipv4_address")}"
  dns_ptr         = "${each.value.name}.${var.cluster_domain}"
}
resource "hcloud_rdns" "floating_ip_default" {
  count = "${var.cluster_enable_floating_ip ? 1 : 0}" # Only if floating ip is enabled

  floating_ip_id  = "${hcloud_floating_ip.default.0.id}"
  ip_address      = "${hcloud_floating_ip.default.0.ip_address}"
  dns_ptr         = "${var.cluster_domain}"
}

# Private network
resource "hcloud_network" "default" {
  name      = "${var.cluster_name}"
  ip_range  = "${var.hcloud_network_ip_range}"

  labels = {
    cluster = "${var.cluster_name}"
  }
}
resource "hcloud_network_subnet" "default" {
  network_id    = "${hcloud_network.default.id}"
  type          = "server"
  network_zone  = "${var.hcloud_network_zone}"
  ip_range      = "${var.hcloud_network_subnet_ip_range}"
}
resource "hcloud_server_network" "node" {
  for_each = "${var.servers}"

  network_id  = "${hcloud_network.default.id}"
  server_id   = "${lookup(hcloud_server.node[each.key], "id")}"
  ip          = "${each.value.private_ip_address}"
}
