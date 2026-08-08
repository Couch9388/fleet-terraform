resource "digitalocean_database_cluster" "mysql" {
  name       = var.database_config.name
  engine     = var.database_config.engine
  version    = var.database_config.version
  size       = var.database_config.size
  region     = var.region
  node_count = var.database_config.node_count

  private_network_uuid = digitalocean_vpc.fleet.id

  tags = ["fleet"]
}

resource "digitalocean_database_db" "fleet" {
  cluster_id = digitalocean_database_cluster.mysql.id
  name       = var.database_config.database_name
}

resource "digitalocean_database_user" "fleet" {
  cluster_id = digitalocean_database_cluster.mysql.id
  name       = var.database_config.database_user
}

# Allow only the App Platform app to connect to the database
resource "digitalocean_database_firewall" "mysql" {
  cluster_id = digitalocean_database_cluster.mysql.id

  rule {
    type  = "app"
    value = digitalocean_app.fleet.id
  }
}
