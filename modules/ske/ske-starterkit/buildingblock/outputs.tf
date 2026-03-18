output "dev_link" {
  value       = "https://${local.name}-dev.${var.dns_zone_name}"
  description = "Public URL for the dev stage application."
}

output "prod_link" {
  value       = "https://${local.name}.${var.dns_zone_name}"
  description = "Public URL for the prod stage application."
}
