output "lz_folder_container_id" {
  value       = var.platform_contract_mode ? null : stackit_resourcemanager_folder.this.container_id
  description = "Container ID of the STACKIT resourcemanager folder created for the landing zone. Tenant projects are created inside this folder. Null in platform contract mode."
}

output "root_container_id" {
  value       = var.platform_contract_mode ? null : local.root_container_id
  description = "Root folder, or the organization without one. Parent for projects of this meshStack that are no tenants."
}

output "foundation_project_id" {
  value       = var.platform_contract_mode ? null : stackit_resourcemanager_project.foundation.project_id
  description = "Project ID of the STACKIT foundation project that hosts the landing-zone core assets (the service account used for tenant project creation). Null in platform contract mode."
}

output "foundation_project_url" {
  value       = var.platform_contract_mode ? null : "https://portal.stackit.cloud/dashboard?project=${stackit_resourcemanager_project.foundation.project_id}"
  description = "Deep link to the foundation project in the STACKIT portal. Null in platform contract mode."
}

output "workload_identity_federation" {
  description = "Issuer, audience and, by definition, the subjects that federated identity providers on `backplane_service_account_email` must match. Null outside platform contract mode."
  value       = var.platform_contract_mode ? local.workload_identity_federation : null
}

output "summary" {
  description = "Summary of the meshStack resources created by this reference architecture."
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    platform_identifier = local.platform_identifier
    playground_mode     = var.playground_mode

    platform_contract_mode       = var.platform_contract_mode
    workload_identity_federation = local.workload_identity_federation
    contract_landing_zones       = var.platform_contract_mode ? { for key, lz in local.contract_landing_zones : key => merge(lz, { name = module.stackit_integration.landingzone_refs[key].name }) } : {}

    organization_id        = local.organization_id
    organization_url       = "https://portal.stackit.cloud/dashboard?organization=${local.organization_id}"
    root_folder_name       = local.root_folder_name == null ? "" : local.root_folder_name
    root_folder_url        = local.root_folder_name == null ? "" : "https://portal.stackit.cloud/dashboard?organization=${var.stackit_org}&folder=${stackit_resourcemanager_folder.root.folder_id}"
    lz_folder_container_id = var.platform_contract_mode ? "" : stackit_resourcemanager_folder.this.container_id
    lz_folder_url          = var.platform_contract_mode ? "" : "https://portal.stackit.cloud/dashboard?organization=${var.stackit_org}&folder=${stackit_resourcemanager_folder.this.folder_id}"
    foundation_project_id  = var.platform_contract_mode ? "" : stackit_resourcemanager_project.foundation.project_id
    foundation_project_url = var.platform_contract_mode ? "" : "https://portal.stackit.cloud/dashboard?project=${stackit_resourcemanager_project.foundation.project_id}"
    service_account_email  = module.stackit_integration.service_account_email
    service_account_url    = var.platform_contract_mode ? "" : "https://portal.stackit.cloud/service-accounts/${module.stackit_integration.service_account_email}/overview?project=${stackit_resourcemanager_project.foundation.project_id}"

    network_enabled            = local.network_enabled
    networked_landingzone_name = local.network_enabled ? module.stackit_integration.landingzone_refs["networked"].name : ""
    network_area_hub_uuid      = local.network_enabled ? meshstack_building_block.network_area_hub.metadata.uuid : ""
    network_area_id            = local.network_enabled ? local.network_area_id : ""
    network_area_url           = local.network_enabled ? "https://portal.stackit.cloud/network-area/network-areas/${local.network_area_id}/overview?organization=${var.stackit_org}" : ""

    platform_ref                                = module.stackit_integration.platform_ref
    landingzone_refs                            = module.stackit_integration.landingzone_refs
    service_account_bbd_version_uuid            = module.service_account_integration.building_block_definition.version_ref.uuid
    service_account_federation_bbd_version_uuid = module.service_account_federation_integration.building_block_definition.version_ref.uuid
    identity_definitions_released = alltrue([
      for version in [
        module.service_account_integration.building_block_definition.version_ref,
        module.service_account_federation_integration.building_block_definition.version_ref,
      ] : version.state == "RELEASED"
    ])
  })
}
