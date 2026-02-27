output "github_repo_bbd_uuid" {
  description = "UUID of the GitHub repository building block definition."
  value       = module.github_repo_bbd.bbd_uuid
}

output "github_repo_bbd_version_uuid" {
  description = "UUID of the latest version of the GitHub repository building block definition."
  value       = module.github_repo_bbd.bbd_version_uuid
}

output "github_connector_bbd_version_uuid" {
  description = "UUID of the latest version of the GitHub Actions connector building block definition."
  value       = module.github_connector_bbd.bbd_version_uuid
}
