variable "region" {
  description = "The DigitalOcean region for all resources."
  type        = string
  default     = "nyc3"
}

variable "prefix" {
  description = "A prefix used for naming resources."
  type        = string
  default     = "fleet"
}

variable "domain_name" {
  description = "The domain name for Fleet (e.g., 'fleet.example.com'). A DigitalOcean DNS zone and A record will be created."
  type        = string
}

variable "vpc_config" {
  description = "Configuration for the DigitalOcean VPC."
  type = object({
    name     = string
    ip_range = string
  })
  default = {
    name     = "fleet-network"
    ip_range = "10.10.10.0/24"
  }
}

variable "fleet_config" {
  description = <<-EOT
    Configuration for the Fleet application deployment on App Platform.

    image_tag accepts a full image reference:
      - Docker Hub: "fleetdm/fleet:v4.90.0" (default, official image)
      - Docker Hub custom: "your-org/your-image:v1.0.0"
      - DOCR: "registry.digitalocean.com/your-registry/your-image:v1.0.0"

    image_registry_credentials: "username:token" for private Docker Hub repos.
    image_deploy_on_push: auto-deploy when a new image is pushed (DOCR only).
  EOT
  type = object({
    image_tag                  = string
    image_registry_credentials = optional(string)
    image_deploy_on_push       = optional(bool, false)
    instance_size_slug         = string
    instance_count             = number
    license_key                = optional(string)
    debug_logging              = bool
    exec_migration             = bool
    extra_env_vars             = optional(map(string))
  })
  default = {
    image_tag          = "fleetdm/fleet:v4.90.0"
    instance_size_slug = "apps-s-1vcpu-1gb"
    instance_count     = 1
    debug_logging      = false
    exec_migration     = true
    extra_env_vars     = {}
  }
}

variable "database_config" {
  description = "Configuration for the MySQL database. Set node_count=0 to use a self-hosted Droplet instead of managed."
  type = object({
    name                = string
    engine              = string
    version             = string
    size                = string
    node_count          = number
    database_name       = string
    database_user       = string
    deletion_protection = optional(bool, false)
    droplet_size        = optional(string, "s-1vcpu-512mb") # Only used when node_count=0
  })
  default = {
    name          = "fleet-mysql"
    engine        = "mysql"
    version       = "8"
    size          = "db-s-1vcpu-1gb"
    node_count    = 1
    database_name = "fleet"
    database_user = "fleet"
  }
}

variable "cache_config" {
  description = "Configuration for the managed Valkey (Redis-compatible) cache cluster."
  type = object({
    name       = string
    engine     = string
    version    = string
    size       = string
    node_count = number
  })
  default = {
    name       = "fleet-cache"
    engine     = "valkey"
    version    = "8"
    size       = "db-s-1vcpu-1gb"
    node_count = 1
  }
}
