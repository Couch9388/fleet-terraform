# Extract the zone (e.g., "example.com") from the FQDN (e.g., "fleet.example.com")
locals {
  zone_name = join(".", slice(split(".", var.domain_name), 1, length(split(".", var.domain_name))))
}

resource "digitalocean_domain" "fleet" {
  name = local.zone_name
}

resource "digitalocean_record" "fleet" {
  domain = digitalocean_domain.fleet.id
  type   = "CNAME"
  name   = split(".", var.domain_name)[0]
  value  = "${digitalocean_app.fleet.default_ingress}."
  ttl    = 300
}
