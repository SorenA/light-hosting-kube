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
  for_each = "${var.servers}"

  image       = "${var.hcloud_image}"
  location    = "${var.hcloud_location}"
  backups     = "${var.hcloud_backups}"

  name        = "${each.value.name}.${var.cluster_domain}"
  server_type = "${each.value.server_type}"

  ssh_keys    = ["${hcloud_ssh_key.default.name}"]

  labels = {
    cluster = "${var.cluster_name}"
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