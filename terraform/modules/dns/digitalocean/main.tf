provider "digitalocean" {
  version = "~> 1.11"
  token = var.digitalocean_token
}

resource "digitalocean_domain" "default" {
  name = var.cluster_domain
}

resource "digitalocean_record" "nodes" {
  for_each = var.servers

  domain   = digitalocean_domain.default.name
  type     = "A"
  name     = each.value.name
  value    = var.server_ips[each.key]
  ttl      = 600
}

resource "digitalocean_record" "floating_ip" {
  count = var.cluster_enable_floating_ip ? 1 : 0 # Only if floating ip is enabled

  domain   = digitalocean_domain.default.name
  type     = "A"
  name     = "@"
  value    = var.floating_ip
  ttl      = 600
}

resource "digitalocean_record" "cluster_cname" {
  count = var.cluster_enable_floating_ip ? 1 : 0 # Only if floating ip is enabled

  domain   = digitalocean_domain.default.name
  type     = "CNAME"
  name     = "*."
  value    = "@"
  ttl      = 600
}
