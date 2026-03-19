output "app_link_dev" {
  value       = "https://${local.app_hostnames["dev"]}"
  description = "Public URL for the dev stage application."
}

output "app_link_prod" {
  value       = "https://${local.app_hostnames["prod"]}"
  description = "Public URL for the prod stage application."
}
