resource "azuredevops_git_repository_file" "pipeline_yaml" {
  repository_id = var.repository_id
  file          = var.yaml_path
  content = templatefile("${path.module}/templates/azure-pipelines.yml.tpl", {
    agent_pool_name         = var.agent_pool_name
    service_connection_name = var.service_connection_name
    repository_name         = var.repository_name
  })
  branch              = var.branch_name
  commit_message      = "Add pipeline definition"
  overwrite_on_create = true
}

resource "azuredevops_build_definition" "main" {
  project_id = var.project_id
  name       = var.pipeline_name

  ci_trigger {
    use_yaml = true
  }

  repository {
    repo_type   = var.repository_type
    repo_id     = var.repository_id
    branch_name = var.branch_name
    yml_path    = var.yaml_path
  }

  variable_groups = length(var.variable_group_ids) > 0 ? var.variable_group_ids : null

  dynamic "variable" {
    for_each = var.pipeline_variables
    content {
      name           = variable.value.name
      value          = variable.value.value
      is_secret      = lookup(variable.value, "is_secret", false)
      allow_override = lookup(variable.value, "allow_override", true)
    }
  }
}
