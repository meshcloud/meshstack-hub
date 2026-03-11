output "forgejo_base_url" {
  value       = var.forgejo_base_url
  description = "STACKIT Git base URL"
}

output "forgejo_token" {
  value       = var.forgejo_token
  description = "STACKIT Git API token for use by building block instances"
  sensitive   = true
}

output "forgejo_organization" {
  value       = var.forgejo_organization
  description = "Default STACKIT Git organization for repository creation"
}
