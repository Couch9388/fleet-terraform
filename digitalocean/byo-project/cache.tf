# ============================================================================
# Cache Configuration
# node_count >= 1: Creates managed Valkey cluster
# node_count = 0:  Skips cache entirely (Fleet uses in-memory)
# ============================================================================

resource "digitalocean_database_cluster" "cache" {
  count = var.cache_config.node_count >= 1 ? 1 : 0

  name       = var.cache_config.name
  engine     = var.cache_config.engine
  version    = var.cache_config.version
  size       = var.cache_config.size
  region     = var.region
  node_count = var.cache_config.node_count

  private_network_uuid = digitalocean_vpc.fleet.id

  tags = ["fleet"]
}

resource "digitalocean_database_firewall" "cache" {
  count = var.cache_config.node_count >= 1 ? 1 : 0

  cluster_id = digitalocean_database_cluster.cache[0].id

  rule {
    type  = "app"
    value = digitalocean_app.fleet.id
  }
}

locals {
  cache_enabled = var.cache_config.node_count >= 1
  cache_host    = local.cache_enabled ? digitalocean_database_cluster.cache[0].host : ""
  cache_port    = local.cache_enabled ? digitalocean_database_cluster.cache[0].port : 0
  cache_password = local.cache_enabled ? digitalocean_database_cluster.cache[0].password : ""
}
