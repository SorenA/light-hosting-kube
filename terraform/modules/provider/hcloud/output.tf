output "server_ips" {
  value = {for key, value in var.servers : key => "${lookup(hcloud_server.node[key], "ipv4_address")}"}
}
output "floating_ip" {
  value = "${var.cluster_enable_floating_ip && length(hcloud_floating_ip.default) > 0 ? hcloud_floating_ip.default.0.ip_address : ""}"
}