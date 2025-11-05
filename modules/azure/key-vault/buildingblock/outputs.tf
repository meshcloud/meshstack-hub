output "key_vault_id" {
  description = "The ID of the Azure Key Vault"
  value       = azurerm_key_vault.key_vault.id
}

output "key_vault_name" {
  description = "The name of the Azure Key Vault"
  value       = azurerm_key_vault.key_vault.name
}

output "key_vault_uri" {
  description = "The URI of the Azure Key Vault"
  value       = azurerm_key_vault.key_vault.vault_uri
}

output "key_vault_resource_group" {
  description = "Name of the resource group containing the Key Vault"
  value       = azurerm_resource_group.key_vault.name
}

output "private_endpoint_ip" {
  description = "Private IP address of the Key Vault private endpoint"
  value       = var.private_endpoint_enabled ? azurerm_private_endpoint.key_vault_pe[0].private_service_connection[0].private_ip_address : null
}

output "vnet_id" {
  description = "ID of the virtual network used for private endpoint"
  value       = local.vnet_id
}

output "subnet_id" {
  description = "ID of the subnet used for private endpoint"
  value       = local.subnet_id
}

output "private_dns_zone_id" {
  description = "ID of the private DNS zone (when System-managed)"
  value       = var.private_endpoint_enabled && var.private_dns_zone_id == "System" ? azurerm_private_dns_zone.key_vault_dns[0].id : null
}
