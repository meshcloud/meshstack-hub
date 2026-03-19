output "app_link" {
  description = "Public URL for this stage application."
  value       = "https://${var.app_hostname}"
}

output "user_permissions" {
  description = "Stage-scoped Forgejo user permissions derived from meshStack project members."
  value       = local.user_permissions
}
