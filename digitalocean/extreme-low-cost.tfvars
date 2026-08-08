# ============================================================================
# EXTREME LOW-COST DigitalOcean Fleet Terraform Configuration
# Target: ~$9-11/month (down from ~$47/month — 77-81% savings!)
# Use Case: Tiny deployments (up to 10 devices), absolute minimum cost
# ============================================================================
#
# EXTREME OPTIMIZATIONS APPLIED:
# - Smallest App Platform instance (basic-xxs, 512 MiB) — SAVES $7/month
# - NO managed Valkey/Redis (in-memory cache) — SAVES $15/month
# - Self-hosted MySQL on Droplet (replaces managed) — SAVES $9-11/month
# - Total additional savings: $31-33/month vs default
#
# TRADEOFFS:
# - 512 MiB RAM may be tight for Fleet (monitor memory usage)
# - No managed database backups (you manage your own)
# - No database failover (single Droplet)
# - No Redis caching (slower queries)
# - Droplet requires manual security updates
# ============================================================================

# ----------------------------------------------------------------------------
# Required: Domain name for Fleet
# ----------------------------------------------------------------------------
# domain_name = "fleet.your-domain.com"  # Set this!

# ----------------------------------------------------------------------------
# App Platform — smallest possible instance
# ----------------------------------------------------------------------------
fleet_config = {
  # Image — use the official Fleet image or your own:
  #   Official:            "fleetdm/fleet:v4.90.0"
  #   Custom Docker Hub:   "your-org/your-fleet:v1.0.0"
  #   DigitalOcean DOCR:   "registry.digitalocean.com/your-registry/fleet:v1.0.0"
  image_tag          = "fleetdm/fleet:v4.90.0"
  # image_registry_credentials = "your-username:your-token"  # private Docker Hub
  # image_deploy_on_push = true                              # DOCR only
  instance_size_slug = "basic-xxs"  # $5/mo — 512 MiB, 1 shared vCPU
  instance_count     = 1
  debug_logging      = false
  exec_migration     = true
  extra_env_vars = {
    # Disable Redis — Fleet falls back to in-memory cache
    FLEET_REDIS_ADDRESS = ""
  }
}

# ----------------------------------------------------------------------------
# Database — self-hosted on Droplet (managed disabled)
# ----------------------------------------------------------------------------
database_config = {
  name          = "fleet-mysql"
  engine        = "mysql"
  version       = "8"
  size          = "db-s-1vcpu-1gb"  # Not used when self-hosted
  node_count    = 0                # 0 = use self-hosted Droplet instead
  database_name = "fleet"
  database_user = "fleet"
}

# ----------------------------------------------------------------------------
# Cache — disabled
# ----------------------------------------------------------------------------
cache_config = {
  name       = "fleet-cache"
  engine     = "valkey"
  version    = "8"
  size       = "db-s-1vcpu-1gb"  # Not used when disabled
  node_count = 0                # 0 = disabled
}

# ----------------------------------------------------------------------------
# VPC — kept for network isolation between app and Droplet
# ----------------------------------------------------------------------------
vpc_config = {
  name     = "fleet-network"
  ip_range = "10.10.10.0/24"
}
