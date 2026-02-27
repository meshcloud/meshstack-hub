output "git_repo_bbd_uuid" {
  description = "UUID of the STACKIT Git repository building block definition."
  value       = module.git_repo_bbd.bbd_uuid
}

output "git_repo_bbd_version_uuid" {
  description = "UUID of the latest version of the STACKIT Git repository building block definition."
  value       = module.git_repo_bbd.bbd_version_uuid
}

output "forgejo_connector_bbd_version_uuid" {
  description = "UUID of the latest version of the Forgejo Actions connector building block definition."
  value       = module.forgejo_connector_bbd.bbd_version_uuid
}
