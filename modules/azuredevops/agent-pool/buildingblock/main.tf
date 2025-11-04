data "azurerm_key_vault" "devops" {
  name                = var.key_vault_name
  resource_group_name = var.resource_group_name
}

data "azurerm_key_vault_secret" "azure_devops_pat" {
  name         = var.pat_secret_name
  key_vault_id = data.azurerm_key_vault.devops.id
}

data "azurerm_virtual_machine_scale_set" "existing" {
  name                = var.vmss_name
  resource_group_name = var.vmss_resource_group_name
}

resource "azuredevops_agent_pool" "main" {
  name           = var.agent_pool_name
  auto_provision = var.auto_provision
  auto_update    = var.auto_update
  pool_type      = "automation"
}

resource "azuredevops_elastic_pool" "main" {
  name                   = var.agent_pool_name
  service_endpoint_id    = var.service_endpoint_id
  service_endpoint_scope = var.service_endpoint_scope
  azure_resource_id      = data.azurerm_virtual_machine_scale_set.existing.id
  max_capacity           = var.max_capacity
  desired_idle           = var.desired_idle
  recycle_after_each_use = var.recycle_after_each_use
  time_to_live_minutes   = var.time_to_live_minutes
  agent_interactive_ui   = var.agent_interactive_ui

  depends_on = [azuredevops_agent_pool.main]
}

resource "azuredevops_agent_queue" "main" {
  count = var.project_id != null ? 1 : 0

  project_id    = var.project_id
  agent_pool_id = azuredevops_agent_pool.main.id
}

resource "azuredevops_pipeline_authorization" "main" {
  count = var.project_id != null ? 1 : 0

  project_id  = var.project_id
  resource_id = azuredevops_agent_queue.main[0].id
  type        = "queue"
}
