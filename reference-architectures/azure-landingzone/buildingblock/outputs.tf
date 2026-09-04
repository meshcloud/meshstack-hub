output "platform_ref" {
  description = "Reference to the meshPlatform this architecture creates, for compositions that create meshTenants (subscriptions) on it."
  value       = module.azure_platform.platform_ref
}

output "landingzone_refs" {
  description = "References to the created landing zones, keyed by archetype (`corp`, `online`, `sandbox`)."
  value       = module.azure_platform.landingzone_refs
}

output "landingzone_names" {
  description = "meshStack landing zone names created per archetype."
  value       = module.azure_platform.landingzone_names
}

output "budget_alert_bbd" {
  description = "Reference to the Azure Budget Alert building block definition registered by this architecture."
  value       = module.budget_alert.building_block_definition
}

output "storage_account_bbd" {
  description = "Reference to the Azure Storage Account building block definition registered by this architecture."
  value       = module.storage_account.building_block_definition
}

output "spoke_network_bbd" {
  description = "Reference to the Azure Spoke Network building block definition registered by this architecture."
  value       = module.spoke_network.building_block_definition
}

output "hub_network_bbd" {
  description = "Reference to the Azure Hub Network building block definition registered by this architecture, or null when foundation.hub is not set."
  value       = local.hub_enabled ? module.hub_network.building_block_definition : null
}

output "summary" {
  description = "Summary of the meshStack resources created by this reference architecture."
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    platform_identifier    = local.platform_identifier
    playground_mode        = var.playground_mode
    management_group       = local.lz_management_group
    corp_management_group  = local.corp_management_group
    online_mgmt_group      = local.online_management_group
    sandbox_mgmt_group     = local.sandbox_management_group
    landingzone_names      = module.azure_platform.landingzone_names
    hub_vnet               = local.spoke_hub.vnet_name
    hub_resource_group     = local.spoke_hub.resource_group_name
    platform_subscription  = var.azure_platform_subscription_id
    backplane_subscription = local.backplane_subscription_id
    hub_provisioned        = local.hub_enabled
    policies_enabled       = local.policies_enabled
    foundation_rg_names    = keys(local.foundation_rgs)
  })
}
