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
  description = "The domain name for Fleet (e.g., 'fleet.example.com')."
  type        = string
}

variable "vpc_config" {
  description = "Configuration for the DigitalOcean VPC."
  type = object({
    name     = string
    ip_range = string
  })
}

variable "fleet_config" {
  description = "Configuration for the Fleet application deployment. image_tag accepts full image references from Docker Hub or DOCR."
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
    droplet_size        = optional(string, "s-1vcpu-512mb")
  })
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
}
