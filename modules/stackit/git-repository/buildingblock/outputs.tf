locals {
  repository     = jsondecode(restapi_object.repository.api_data)
  repo_html_url  = local.repository.html_url
  repo_ssh_url   = local.repository.ssh_url
  repo_clone_url = local.repository.clone_url
}

output "repository_id" {
  value       = local.repository.id
  description = "The ID of the created repository"
}

output "repository_name" {
  value       = var.name
  description = "Name of the created repository"
}

output "repository_html_url" {
  value       = local.repo_html_url
  description = "Web URL of the repository"
}

output "repository_ssh_url" {
  value       = local.repo_ssh_url
  description = "SSH clone URL"
}

output "repository_clone_url" {
  value       = local.repo_clone_url
  description = "HTTPS clone URL"
}

output "summary" {
  description = "Summary with next steps and links for the created repository"
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    name                = var.name
    owner               = var.forgejo_organization
    repo_html_url       = local.repo_html_url
    repo_clone_url      = local.repo_clone_url
    use_template        = var.use_template
    template_repo_path  = var.template_repo_path
    default_branch      = var.default_branch
    webhook_url         = var.webhook_url
    webhook_events_text = join(", ", var.webhook_events)
  })
}
