# The `app_link_<stage>` outputs are written by prerun.sh, one per stage.

output "summary" {
  description = "Summary with next steps and insights into created resources"
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    workspace_identifier = var.workspace_identifier
    app_name             = var.app_name
    repo_clone_addr      = var.repo_clone_addr
    git_repository_uuid  = meshstack_building_block.git_repository.metadata.uuid
    repo_html_url        = jsondecode(meshstack_building_block.git_repository.status.outputs.repository_html_url.value)

    stages = [
      for stage in sort(keys(meshstack_project.this)) : {
        name                   = stage
        project_workspace      = meshstack_project.this[stage].metadata.owned_by_workspace
        project_name           = meshstack_project.this[stage].metadata.name
        tenant_uuid            = meshstack_tenant.this[stage].metadata.uuid
        forgejo_connector_uuid = meshstack_building_block.forgejo_connector[stage].metadata.uuid
        app_hostname           = local.app_hostnames[stage]
      }
    ]
  })
}
