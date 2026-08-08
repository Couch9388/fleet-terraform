output "fleet_application_url" {
  description = "The primary URL to access the Fleet application."
  value       = module.fleet.fleet_application_url
}

output "app_id" {
  description = "The ID of the DigitalOcean App Platform app."
  value       = module.fleet.app_id
}

output "app_live_url" {
  description = "The live URL assigned by App Platform."
  value       = module.fleet.app_live_url
}

output "database_host" {
  description = "The hostname of the MySQL database cluster."
  value       = module.fleet.database_host
}

output "database_port" {
  description = "The port of the MySQL database cluster."
  value       = module.fleet.database_port
}

output "cache_host" {
  description = "The hostname of the Valkey cache cluster."
  value       = module.fleet.cache_host
}

output "cache_port" {
  description = "The port of the Valkey cache cluster."
  value       = module.fleet.cache_port
}

output "spaces_bucket_name" {
  description = "The name of the Spaces bucket for Fleet software installers."
  value       = module.fleet.spaces_bucket_name
}

output "spaces_bucket_endpoint" {
  description = "The endpoint of the Spaces bucket."
  value       = module.fleet.spaces_bucket_endpoint
}

output "vpc_id" {
  description = "The ID of the VPC."
  value       = module.fleet.vpc_id
}

output "dns_record_fqdn" {
  description = "The FQDN of the DNS record for Fleet."
  value       = module.fleet.dns_record_fqdn
}
