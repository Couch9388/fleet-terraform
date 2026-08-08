resource "digitalocean_vpc" "fleet" {
  name     = var.vpc_config.name
  region   = var.region
  ip_range = var.vpc_config.ip_range
}
