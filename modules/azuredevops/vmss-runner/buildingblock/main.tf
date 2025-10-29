data "azurerm_subnet" "spoke" {
  name                 = var.spoke_subnet_name
  virtual_network_name = var.spoke_vnet_name
  resource_group_name  = var.spoke_resource_group_name
}

resource "azuredevops_agent_pool" "vmss" {
  name           = var.agent_pool_name
  auto_provision = false
  auto_update    = true
}

resource "azuredevops_agent_queue" "vmss" {
  project_id    = var.azuredevops_project_id
  agent_pool_id = azuredevops_agent_pool.vmss.id
}

resource "azuredevops_elastic_pool" "vmss" {
  name                   = var.vmss_name
  service_endpoint_id    = var.service_endpoint_id
  service_endpoint_scope = var.azuredevops_project_id
  desired_idle           = var.desired_idle_agents
  max_capacity           = var.max_capacity
  azure_resource_id      = azurerm_linux_virtual_machine_scale_set.vmss.id
  agent_interactive_ui   = false
  time_to_live_minutes   = var.time_to_live_minutes
  recycle_after_each_use = var.recycle_after_each_use

  depends_on = [
    azuredevops_agent_pool.vmss
  ]
}

resource "azurerm_linux_virtual_machine_scale_set" "vmss" {
  name                = var.vmss_name
  resource_group_name = var.azure_resource_group_name
  location            = var.azure_location
  sku                 = var.vm_sku
  instances           = var.desired_idle_agents
  admin_username      = "azureuser"

  admin_ssh_key {
    username   = "azureuser"
    public_key = var.ssh_public_key
  }

  source_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = var.image_version
  }

  os_disk {
    storage_account_type = var.os_disk_type
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "${var.vmss_name}-nic"
    primary = true

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = data.azurerm_subnet.spoke.id
    }
  }

  identity {
    type = "SystemAssigned"
  }

  extension {
    name                       = "AzureDevOpsAgent"
    publisher                  = "Microsoft.Azure.Extensions"
    type                       = "CustomScript"
    type_handler_version       = "2.1"
    auto_upgrade_minor_version = true

    settings = jsonencode({
      fileUris = [var.agent_script_url]
    })

    protected_settings = jsonencode({
      commandToExecute = "bash install-agent.sh '${var.azuredevops_org_url}' '${var.azuredevops_pat}' '${azuredevops_agent_pool.vmss.name}'"
    })
  }

  tags = var.tags
}

resource "azurerm_role_assignment" "vmss_contributor" {
  scope                = data.azurerm_subnet.spoke.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_linux_virtual_machine_scale_set.vmss.identity[0].principal_id
}
