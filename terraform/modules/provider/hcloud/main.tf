provider "hcloud" {
  version = "~> 1.14"
  token = "${var.hcloud_token}"
}

# SSH
resource "hcloud_ssh_key" "default" {
  name       = "${var.cluster_name}-${var.ssh_public_key_name}"
  public_key = "${file(var.ssh_public_key)}"
}

# Servers
resource "hcloud_server" "node" {
  // for_each with provisioner using self causes Terraform to crash in v0.12.12: https://github.com/hashicorp/terraform/issues/23191
  //for_each = "${var.servers}"
  //name        = "${each.value.name}.${var.cluster_domain}"
  //server_type = "${each.value.server_type}"

  // Provision using count instead
  count       = "${length(values(var.servers))}"
  name        = "${lookup(element(values(var.servers), count.index), "name")}.${var.cluster_domain}"
  server_type = "${lookup(element(values(var.servers), count.index), "server_type")}"

  image       = "${var.hcloud_image}"
  location    = "${var.hcloud_location}"
  backups     = "${var.hcloud_backups}"
  ssh_keys    = ["${hcloud_ssh_key.default.name}"]

  labels = {
    cluster = "${var.cluster_name}"
  }

  # Set hostname
  provisioner "remote-exec" {
    inline = [
      "sudo hostnamectl set-hostname ${self.name}",
    ]

    connection {
      host        = "${self.ipv4_address}"
    }
  }

  # Run Ansible playbook for provisioning setup
  provisioner "local-exec" {
    command = "cd ${path.root}/../../../ansible/ && ANSIBLE_CONFIG=ansible.cfg ansible-playbook -i '${self.ipv4_address},' --extra-vars 'ansible_user=root floating_ip=${hcloud_floating_ip.default.ip_address}' provision.yml"
  }
}

# Floating IP
resource "hcloud_floating_ip" "default" {
  type          = "ipv4"
  description   = "${var.cluster_domain}"
  home_location = "${var.hcloud_location}"

  labels = {
    cluster = "${var.cluster_name}"
  }
}

# Reverse DNS
resource "hcloud_rdns" "node" {
  for_each = "${hcloud_server.node}"

  server_id       = "${each.value.id}"
  ip_address      = "${each.value.ipv4_address}"
  dns_ptr         = "${each.value.name}"
}
resource "hcloud_rdns" "floating_ip_default" {
  floating_ip_id  = "${hcloud_floating_ip.default.id}"
  ip_address      = "${hcloud_floating_ip.default.ip_address}"
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
  ip_range      = "${var.hcloud_network_ip_range}"
}
resource "hcloud_server_network" "node" {
  for_each = "${var.servers}"

  network_id  = "${hcloud_network.default.id}"
  server_id   = "${lookup(hcloud_server.node[each.key], "id")}"
  ip          = "${each.value.private_ip_address}"
}
