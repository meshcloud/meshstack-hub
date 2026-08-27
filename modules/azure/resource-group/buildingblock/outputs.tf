output "resource_group_name" {
  value       = azurerm_resource_group.this.name
  description = "The name of the created resource group (e.g. 'rg-myworkspace-myproject')."
}

output "resource_group_id" {
  value       = azurerm_resource_group.this.id
  description = "The Azure resource ID of the created resource group."
}
