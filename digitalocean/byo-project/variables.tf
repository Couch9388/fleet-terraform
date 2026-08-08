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
  description = "Configuration for the Fleet application deployment."
  type = object({
    image_tag          = string
    instance_size_slug = string
    instance_count     = number
    license_key        = optional(string)
    debug_logging      = bool
    exec_migration     = bool
    extra_env_vars     = optional(map(string))
  })
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
