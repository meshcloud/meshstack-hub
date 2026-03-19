output "app_link" {
  description = "Public URL for this stage application."
  value       = "https://${var.app_hostname}"
}
