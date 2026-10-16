
output "dev-link" {
  description = "Link to the dev environment Angular app"
  value       = "https://${local.identifier}-dev.${var.apps_base_domain}"
}

output "prod-link" {
  description = "Link to the prod environment Angular app"
  value       = "https://${local.identifier}.${var.apps_base_domain}"
}

output "github_repo_url" {
  description = "URL of the created GitHub repository"
  value       = jsondecode(meshstack_building_block.repo.status.outputs.repo_html_url.value)
}

output "summary" {
  description = "Summary with next steps and insights into created resources"
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    workspace_identifier = var.workspace_identifier
    identifier           = local.identifier
    apps_base_domain     = var.apps_base_domain
    repo_uuid            = meshstack_building_block.repo.metadata.uuid
    repo_html_url        = jsondecode(meshstack_building_block.repo.status.outputs.repo_html_url.value)

    stages = {
      for stage, project in meshstack_project.this : stage => {
        project_workspace   = project.metadata.owned_by_workspace
        project_name        = project.metadata.name
        tenant_uuid         = meshstack_tenant.this[stage].metadata.uuid
        github_actions_uuid = meshstack_building_block.github_actions[stage].metadata.uuid
      }
    }
  })
}
