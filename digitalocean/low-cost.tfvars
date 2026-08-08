# ============================================================================
# LOW-COST DigitalOcean Fleet Terraform Configuration
# Target: ~$32/month (down from ~$47/month — 32% savings)
# Use Case: Small deployments (up to 50 devices), no Redis cache needed
# ============================================================================
#
# OPTIMIZATIONS APPLIED:
# - NO managed Valkey/Redis (Fleet uses in-memory cache) — SAVES $15/month
# - Keeps managed MySQL (recommended for data safety)
# - Keeps App Platform with automatic TLS and scaling
# - Keeps Spaces for software installers
# ============================================================================

# ----------------------------------------------------------------------------
# Required: Domain name for Fleet
# ----------------------------------------------------------------------------
# domain_name = "fleet.your-domain.com"  # Set this!

# ----------------------------------------------------------------------------
# App Platform — same as default, but without Redis env vars
# ----------------------------------------------------------------------------
fleet_config = {
  # Image — use the official Fleet image or your own:
  #   Official:            "fleetdm/fleet:v4.90.0"
  #   Custom Docker Hub:   "your-org/your-fleet:v1.0.0"
  #   DigitalOcean DOCR:   "registry.digitalocean.com/your-registry/fleet:v1.0.0"
  image_tag          = "fleetdm/fleet:v4.90.0"
  # image_registry_credentials = "your-username:your-token"  # private Docker Hub
  # image_deploy_on_push = true                              # DOCR only
  instance_size_slug = "apps-s-1vcpu-1gb"  # $12/mo
  instance_count     = 1
  debug_logging      = false
  exec_migration     = true
  extra_env_vars = {
    # Disable Redis — Fleet falls back to in-memory cache
    FLEET_REDIS_ADDRESS = ""
  }
}

# ----------------------------------------------------------------------------
# Managed MySQL — kept as managed for data safety
# ----------------------------------------------------------------------------
database_config = {
  name          = "fleet-mysql"
  engine        = "mysql"
  version       = "8"
  size          = "db-s-1vcpu-1gb"  # $15/mo
  node_count    = 1
  database_name = "fleet"
  database_user = "fleet"
}

# ----------------------------------------------------------------------------
# Cache — disabled by using minimal size (will be skipped via count)
# ----------------------------------------------------------------------------
cache_config = {
  name       = "fleet-cache"
  engine     = "valkey"
  version    = "8"
  size       = "db-s-1vcpu-1gb"  # Not used when disabled
  node_count = 0                # 0 = disabled
}

# ----------------------------------------------------------------------------
# VPC — kept for network isolation
# ----------------------------------------------------------------------------
vpc_config = {
  name     = "fleet-network"
  ip_range = "10.10.10.0/24"
}
