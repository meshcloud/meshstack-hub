data "azurerm_key_vault" "devops" {
  name                = var.key_vault_name
  resource_group_name = var.resource_group_name
}

data "azurerm_key_vault_secret" "azure_devops_pat" {
  name         = var.pat_secret_name
  key_vault_id = data.azurerm_key_vault.devops.id
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
