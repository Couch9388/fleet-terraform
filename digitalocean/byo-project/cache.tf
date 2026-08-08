resource "digitalocean_database_cluster" "cache" {
  name       = var.cache_config.name
  engine     = var.cache_config.engine
  version    = var.cache_config.version
  size       = var.cache_config.size
  region     = var.region
  node_count = var.cache_config.node_count

  private_network_uuid = digitalocean_vpc.fleet.id

  tags = ["fleet"]
}

# Allow only the App Platform app to connect to the cache
resource "digitalocean_database_firewall" "cache" {
  cluster_id = digitalocean_database_cluster.cache.id

  rule {
    type  = "app"
    value = digitalocean_app.fleet.id
  }
}
