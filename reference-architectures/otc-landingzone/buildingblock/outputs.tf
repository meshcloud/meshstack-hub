output "platform_identifier" {
  value       = local.platform_identifier
  description = "Identifier of the created meshStack platform, including the playground suffix."
}

output "console_login_url" {
  value       = coalesce(module.otc_integration.identity_provider_login_link, "https://console.otc.t-systems.com")
  description = "Where project users sign in: the identity provider's login link, or the plain console without federation."
}

output "summary" {
  description = "Summary of what this reference architecture created, and whether an identity provider still has to be connected."
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    platform_identifier = local.platform_identifier
    playground_mode     = var.playground_mode
    domain_name         = var.otc_domain_name
    region              = var.otc_region
    landingzone_name    = module.otc_integration.landingzone_ref.name
    backplane_user_name = "mesh-${local.platform_identifier}"
    management_project  = meshstack_project.management.metadata.name

    federation_enabled         = local.federation_enabled
    identity_provider_name     = local.federation_enabled ? var.identity_provider.name : ""
    identity_provider_protocol = local.federation_enabled ? var.identity_provider.protocol : ""
    email_attribute            = local.federation_enabled ? var.identity_provider.email_attribute : ""
    login_link                 = coalesce(module.otc_integration.identity_provider_login_link, "https://console.otc.t-systems.com")
    federation_mapping_bb_uuid = local.federation_enabled ? meshstack_building_block.federation_mapping.metadata.uuid : ""
  })
}
