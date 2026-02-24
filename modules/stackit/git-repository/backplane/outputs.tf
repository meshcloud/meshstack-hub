output "gitea_base_url" {
  value       = var.gitea_base_url
  description = "STACKIT Git base URL"
}

output "gitea_token" {
  value       = var.gitea_token
  description = "STACKIT Git API token for use by building block instances"
  sensitive   = true
}

output "gitea_organization" {
  value       = var.gitea_organization
  description = "Default STACKIT Git organization for repository creation"
}
