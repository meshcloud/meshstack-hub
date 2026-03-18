output "dev_link" {
  value       = "https://${var.name}-dev.${var.apps_base_domain}"
  description = "Public URL for the dev stage application."
}

output "prod_link" {
  value       = "https://${var.name}.${var.apps_base_domain}"
  description = "Public URL for the prod stage application."
}
