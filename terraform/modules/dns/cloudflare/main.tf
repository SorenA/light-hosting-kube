provider "cloudflare" {
  version = "~> 2.0"
  email   = "${var.cloudflare_email}"
  api_key = "${var.cloudflare_api_key}"
}

resource "cloudflare_record" "floating_ip" {
  zone_id = "${var.cloudflare_zone_id}"
  name    = "${var.cluster_domain}"
  value   = "${var.floating_ip}"
  type    = "A"
  proxied = false
  ttl     = 3600
}

resource "cloudflare_record" "nodes" {
  for_each = "${var.servers}"

  zone_id = "${var.cloudflare_zone_id}"
  name    = "${each.value.name}.${var.cluster_domain}"
  value   = "${var.server_ips[each.key]}"
  type    = "A"
  proxied = false
  ttl     = 3600
}