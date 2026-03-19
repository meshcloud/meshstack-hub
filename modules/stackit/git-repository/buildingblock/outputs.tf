output "repository_id" {
  value       = forgejo_repository.this.id
  description = "The ID of the created repository"
}

output "repository_name" {
  value       = var.name
  description = "Name of the created repository"
}

output "repository_html_url" {
  value       = forgejo_repository.this.html_url
  description = "Web URL of the repository"
}

output "repository_ssh_url" {
  value       = forgejo_repository.this.ssh_url
  description = "SSH clone URL"
}

output "repository_clone_url" {
  value       = forgejo_repository.this.clone_url
  description = "HTTPS clone URL"
}

output "summary" {
  description = "Summary with next steps and links for the created repository"
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    name           = var.name
    owner          = var.forgejo_organization
    repo_html_url  = forgejo_repository.this.html_url
    repo_clone_url = forgejo_repository.this.clone_url
    clone_addr     = var.clone_addr
    default_branch = var.default_branch

    workspace_member_access            = local.mapped_workspace_members
    stackit_project_id                 = var.stackit_project_id
    stackit_forgejo_access_permissions = join(", ", stackit_authorization_project_custom_role.forgejo_access.permissions)
  })
}
