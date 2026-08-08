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
  description = "Configuration for the Fleet application deployment on App Platform."
  type = object({
    image_tag          = string
    instance_size_slug = string
    instance_count     = number
    license_key        = optional(string)
    debug_logging      = bool
    exec_migration     = bool
    extra_env_vars     = optional(map(string))
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
  description = "Configuration for the managed MySQL database cluster."
  type = object({
    name                = string
    engine              = string
    version             = string
    size                = string
    node_count          = number
    database_name       = string
    database_user       = string
    deletion_protection = optional(bool, false)
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
