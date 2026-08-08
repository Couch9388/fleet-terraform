output "fleet_application_url" {
  description = "The primary URL to access the Fleet application."
  value       = "https://${digitalocean_record.fleet.fqdn}"
}

output "app_id" {
  description = "The ID of the DigitalOcean App Platform app."
  value       = digitalocean_app.fleet.id
}

output "app_live_url" {
  description = "The live URL assigned by App Platform."
  value       = digitalocean_app.fleet.live_url
}

output "app_default_ingress" {
  description = "The default ingress URL for the app."
  value       = digitalocean_app.fleet.default_ingress
}

output "database_host" {
  description = "The hostname of the MySQL database cluster."
  value       = digitalocean_database_cluster.mysql.host
}

output "database_port" {
  description = "The port of the MySQL database cluster."
  value       = digitalocean_database_cluster.mysql.port
}

output "database_user" {
  description = "The MySQL database user for Fleet."
  value       = digitalocean_database_user.fleet.name
}

output "cache_host" {
  description = "The hostname of the Valkey cache cluster."
  value       = digitalocean_database_cluster.cache.host
}

output "cache_port" {
  description = "The port of the Valkey cache cluster."
  value       = digitalocean_database_cluster.cache.port
}

output "spaces_bucket_name" {
  description = "The name of the Spaces bucket for Fleet software installers."
  value       = digitalocean_spaces_bucket.software_installers.name
}

output "spaces_bucket_endpoint" {
  description = "The endpoint of the Spaces bucket."
  value       = digitalocean_spaces_bucket.software_installers.endpoint
}

output "vpc_id" {
  description = "The ID of the VPC."
  value       = digitalocean_vpc.fleet.id
}

output "dns_record_fqdn" {
  description = "The FQDN of the DNS record for Fleet."
  value       = digitalocean_record.fleet.fqdn
}

output "domain_name_servers" {
  description = "The name servers for the DigitalOcean DNS zone. Delegate your domain to these."
  value       = ["ns1.digitalocean.com", "ns2.digitalocean.com", "ns3.digitalocean.com"]
}
