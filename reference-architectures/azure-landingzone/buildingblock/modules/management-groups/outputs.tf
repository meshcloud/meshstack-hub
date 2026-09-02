# meshStack and the building block backplanes reference management groups by name; policy
# assignments and RBAC scopes need the full resource path. Expose both for each group.

output "landing_zones_name" {
  value       = azurerm_management_group.landing_zones.name
  description = "Name (ID) of the Landing Zones management group."
}

output "landing_zones_scope" {
  value       = azurerm_management_group.landing_zones.id
  description = "Full resource path of the Landing Zones management group."
}

output "corp_name" {
  value       = azurerm_management_group.corp.name
  description = "Name (ID) of the Corp management group."
}

output "online_name" {
  value       = azurerm_management_group.online.name
  description = "Name (ID) of the Online management group."
}

output "sandbox_name" {
  value       = azurerm_management_group.sandbox.name
  description = "Name (ID) of the Sandbox management group."
}

output "connectivity_name" {
  value       = azurerm_management_group.connectivity.name
  description = "Name (ID) of the Connectivity management group."
}

output "connectivity_scope" {
  value       = azurerm_management_group.connectivity.id
  description = "Full resource path of the Connectivity management group."
}
