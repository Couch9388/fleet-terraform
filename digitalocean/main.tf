terraform {
  required_version = "~> 1.11"
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = ">= 2.99.0"
    }
  }
}

provider "digitalocean" {
  # Uses DIGITALOCEAN_TOKEN environment variable by default.
  # Spaces access is configured via SPACES_ACCESS_KEY_ID and
  # SPACES_SECRET_ACCESS_KEY environment variables.
}

module "fleet" {
  source = "./byo-project"

  region          = var.region
  prefix          = var.prefix
  domain_name     = var.domain_name
  vpc_config      = var.vpc_config
  fleet_config    = var.fleet_config
  database_config = var.database_config
  cache_config    = var.cache_config
}
