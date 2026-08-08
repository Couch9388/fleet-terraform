# ============================================================================
# FLEET FOR 10 DEVICES — DigitalOcean Terraform Configuration
# Target: ~$30/month
# Use Case: 10 machines, reliable managed database, no unnecessary extras
# ============================================================================
#
# WHAT'S INCLUDED:
# ✅ App Platform (1 GiB RAM) — enough for 10 devices
# ✅ Managed MySQL (db-s-1vcpu-1gb) — safe, backed up, managed
# ✅ Spaces bucket — for software installers
# ✅ VPC + DNS + TLS — automatic
# ✅ Database firewall — only the app can connect
#
# WHAT'S REMOVED:
# ❌ Managed Valkey/Redis — Fleet uses in-memory cache (fine for 10 devices)
# ❌ Extra app instances — single instance is enough
# ❌ HA database nodes — single node is fine for 10 devices
# ============================================================================

# ----------------------------------------------------------------------------
# Required: Set your domain name
# ----------------------------------------------------------------------------
# domain_name = "fleet.your-domain.com"

# ----------------------------------------------------------------------------
# App Platform — 1 GiB RAM, 1 shared vCPU, 40 GiB bandwidth
# $10/month — plenty for 10 devices
# ----------------------------------------------------------------------------
fleet_config = {
  # Image — use the official Fleet image or your own:
  #   Official:            "fleetdm/fleet:v4.90.0"
  #   Custom Docker Hub:   "your-org/your-fleet:v1.0.0"
  #   DigitalOcean DOCR:   "registry.digitalocean.com/your-registry/fleet:v1.0.0"
  image_tag = "fleetdm/fleet:v4.90.0"

  # For private Docker Hub repos:
  # image_registry_credentials = "your-username:your-token"

  # For DOCR: auto-deploy when you push a new image
  # image_deploy_on_push = true

  instance_size_slug = "basic-xs"  # 1 GiB RAM, $10/mo
  instance_count     = 1
  debug_logging      = false
  exec_migration     = true
  extra_env_vars = {
    # Disable Redis — Fleet uses in-memory cache for small deployments
    FLEET_REDIS_ADDRESS = ""
  }
}

# ----------------------------------------------------------------------------
# Managed MySQL — keep this managed for data safety
# $15/month — includes daily backups and point-in-time recovery
# ----------------------------------------------------------------------------
database_config = {
  name          = "fleet-mysql"
  engine        = "mysql"
  version       = "8"
  size          = "db-s-1vcpu-1gb"  # $15/mo
  node_count    = 1                  # 1 = managed cluster
  database_name = "fleet"
  database_user = "fleet"
}

# ----------------------------------------------------------------------------
# Cache — disabled (Fleet uses in-memory for 10 devices)
# ----------------------------------------------------------------------------
cache_config = {
  name       = "fleet-cache"
  engine     = "valkey"
  version    = "8"
  size       = "db-s-1vcpu-1gb"
  node_count = 0  # 0 = disabled
}

# ----------------------------------------------------------------------------
# VPC — private networking between app and database
# ----------------------------------------------------------------------------
vpc_config = {
  name     = "fleet-network"
  ip_range = "10.10.10.0/24"
}

# ============================================================================
# COST BREAKDOWN
# ============================================================================
# App Platform (basic-xs, 1 GiB):     $10/month
# Managed MySQL (db-s-1vcpu-1gb):     $15/month
# Spaces (250 GB included):            $5/month (or $0 if under free tier)
# VPC:                                 Free
# DNS:                                 Free
# TLS (Let's Encrypt):                 Free
# ----------------------------------------------------------------------------
# TOTAL:                              ~$30/month
# ============================================================================
