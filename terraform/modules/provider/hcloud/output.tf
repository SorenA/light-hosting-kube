output "server_ips" {
  value = {for key, value in var.servers : key => "${lookup(hcloud_server.node[key], "ipv4_address")}"}

}
output "floating_ip" {
  value = "${hcloud_floating_ip.default.ip_address}"
}