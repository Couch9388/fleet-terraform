# ============================================================================
# Database Configuration
# Supports two modes:
#   1. Managed MySQL cluster (node_count >= 1) — recommended for production
#   2. Self-hosted MySQL on Droplet (node_count = 0) — lowest cost
# ============================================================================

# --- Managed MySQL Cluster (node_count >= 1) ---

resource "digitalocean_database_cluster" "mysql" {
  count = var.database_config.node_count >= 1 ? 1 : 0

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
  count = var.database_config.node_count >= 1 ? 1 : 0

  cluster_id = digitalocean_database_cluster.mysql[0].id
  name       = var.database_config.database_name
}

resource "digitalocean_database_user" "fleet" {
  count = var.database_config.node_count >= 1 ? 1 : 0

  cluster_id = digitalocean_database_cluster.mysql[0].id
  name       = var.database_config.database_user
}

resource "digitalocean_database_firewall" "mysql" {
  count = var.database_config.node_count >= 1 ? 1 : 0

  cluster_id = digitalocean_database_cluster.mysql[0].id

  rule {
    type  = "app"
    value = digitalocean_app.fleet.id
  }
}

# --- Self-Hosted MySQL Droplet (node_count = 0) ---

resource "digitalocean_droplet" "mysql" {
  count = var.database_config.node_count == 0 ? 1 : 0

  name   = "${var.prefix}-mysql"
  size   = var.database_config.droplet_size
  image  = "mysql-8-0"  # DigitalOcean MySQL 8.0 image
  region = var.region

  vpc_uuid = digitalocean_vpc.fleet.id

  user_data = <<-EOF
    #!/bin/bash
    set -e

    # Create Docker network
    docker network create fleet-network || true

    # Run MySQL container
    docker run -d \
      --name mysql \
      --network fleet-network \
      --restart unless-stopped \
      -e MYSQL_ROOT_PASSWORD=${random_password.mysql_root[0].result} \
      -e MYSQL_DATABASE=${var.database_config.database_name} \
      -e MYSQL_USER=${var.database_config.database_user} \
      -e MYSQL_PASSWORD=${random_password.mysql_user[0].result} \
      -v mysql_data:/var/lib/mysql \
      --memory="384m" \
      --cpus="0.5" \
      mysql:8.0 \
      --default-authentication-plugin=mysql_native_password \
      --max-connections=50 \
      --innodb-buffer-pool-size=128M \
      --skip-log-bin

    # Wait for MySQL to be ready
    sleep 10

    # Create firewall rule to allow only VPC traffic
    iptables -A INPUT -i eth1 -p tcp --dport 3306 -j ACCEPT
    iptables -A INPUT -p tcp --dport 3306 -j DROP
  EOF

  tags = ["fleet", "mysql"]

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = true
  }
}

resource "random_password" "mysql_root" {
  count = var.database_config.node_count == 0 ? 1 : 0

  length  = 32
  special = false
}

resource "random_password" "mysql_user" {
  count = var.database_config.node_count == 0 ? 1 : 0

  length  = 32
  special = false
}

# Firewall to allow only App Platform to reach the MySQL Droplet
resource "digitalocean_firewall" "mysql" {
  count = var.database_config.node_count == 0 ? 1 : 0

  name = "${var.prefix}-mysql-fw"

  droplet_ids = [digitalocean_droplet.mysql[0].id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "3306"
    source_addresses = [digitalocean_vpc.fleet.ip_range]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

# ============================================================================
# Local values for database connection
# ============================================================================

locals {
  # Managed mode
  managed_mysql_host     = var.database_config.node_count >= 1 ? digitalocean_database_cluster.mysql[0].host : ""
  managed_mysql_port     = var.database_config.node_count >= 1 ? digitalocean_database_cluster.mysql[0].port : 0
  managed_mysql_user     = var.database_config.node_count >= 1 ? digitalocean_database_user.fleet[0].name : ""
  managed_mysql_password = var.database_config.node_count >= 1 ? digitalocean_database_user.fleet[0].password : ""

  # Self-hosted mode
  selfhosted_mysql_host     = var.database_config.node_count == 0 ? digitalocean_droplet.mysql[0].ipv4_address_private : ""
  selfhosted_mysql_port     = var.database_config.node_count == 0 ? 3306 : 0
  selfhosted_mysql_user     = var.database_config.node_count == 0 ? var.database_config.database_user : ""
  selfhosted_mysql_password = var.database_config.node_count == 0 ? random_password.mysql_user[0].result : ""

  # Final values used by app
  mysql_host     = var.database_config.node_count >= 1 ? local.managed_mysql_host : local.selfhosted_mysql_host
  mysql_port     = var.database_config.node_count >= 1 ? local.managed_mysql_port : local.selfhosted_mysql_port
  mysql_user     = var.database_config.node_count >= 1 ? local.managed_mysql_user : local.selfhosted_mysql_user
  mysql_password = var.database_config.node_count >= 1 ? local.managed_mysql_password : local.selfhosted_mysql_password
  mysql_database = var.database_config.database_name
}
