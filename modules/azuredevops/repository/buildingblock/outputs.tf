output "repository_id" {
  description = "ID of the created repository"
  value       = azuredevops_git_repository.main.id
}

output "repository_name" {
  description = "Name of the created repository"
  value       = azuredevops_git_repository.main.name
}

output "repository_url" {
  description = "URL of the created repository"
  value       = azuredevops_git_repository.main.url
}

output "ssh_url" {
  description = "SSH URL of the repository"
  value       = azuredevops_git_repository.main.ssh_url
}

output "web_url" {
  description = "Web URL of the repository"
  value       = azuredevops_git_repository.main.web_url
}

output "default_branch" {
  description = "Default branch of the repository"
  value       = azuredevops_git_repository.main.default_branch
}

output "branch_policies_enabled" {
  description = "Whether branch policies are enabled"
  value       = var.enable_branch_policies
}
