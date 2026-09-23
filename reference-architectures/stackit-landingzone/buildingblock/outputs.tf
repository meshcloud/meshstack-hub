output "lz_folder_container_id" {
  value       = stackit_resourcemanager_folder.this.container_id
  description = "Container ID of the STACKIT resourcemanager folder created for the landing zone. Tenant projects are created inside this folder."
}

output "foundation_project_id" {
  value       = stackit_resourcemanager_project.foundation.project_id
  description = "Project ID of the STACKIT foundation project that hosts the landing-zone core assets (the service account used for tenant project creation)."
}

output "foundation_project_url" {
  value       = "https://portal.stackit.cloud/projects/${stackit_resourcemanager_project.foundation.project_id}"
  description = "Deep link to the foundation project in the STACKIT portal."
}

output "starterkit_bbd_version_ref" {
  value       = module.stackit_project_starterkit.building_block_definition.version_ref
  description = "Version ref of the STACKIT Project Starterkit definition this architecture registered. The definition is created inside this run, so it cannot be reached through a module output."
}

output "service_account_bbd_version_ref" {
  value       = module.service_account_integration.building_block_definition.version_ref
  description = "Version ref of the STACKIT Service Account building block definition this landing zone registered. A composing architecture (e.g. the STACKIT Kubernetes Platform) orders this definition to mint a service account with project roles on a target project, then federates its own definitions into it."
}

output "service_account_federation_bbd_version_ref" {
  value       = module.service_account_federation_integration.building_block_definition.version_ref
  description = "Version ref of the STACKIT Service Account Federation definition. A composing architecture orders it as a child of its service account, with the uuids of the definitions that act as that account."
}

output "platform_ref" {
  value       = module.stackit_integration.platform_ref
  description = "Platform ref, used to build other platforms on top"
}

output "landingzone_refs" {
  value       = module.stackit_integration.landingzone_refs
  description = "Landing zone refs of the platform, used to build other platforms on top"
}

output "summary" {
  description = "Summary of the meshStack resources created by this reference architecture."
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    platform_identifier = local.platform_identifier
    playground_mode     = var.playground_mode
    building_block_uuid = var.meshstack_building_block_id

    organization_id        = var.stackit_org
    organization_url       = "https://portal.stackit.cloud/dashboard?organization=${var.stackit_org}"
    lz_folder_container_id = stackit_resourcemanager_folder.this.container_id
    lz_folder_url          = "https://portal.stackit.cloud/dashboard?organization=${var.stackit_org}&folder=${stackit_resourcemanager_folder.this.folder_id}"
    foundation_project_id  = stackit_resourcemanager_project.foundation.project_id
    foundation_project_url = "https://portal.stackit.cloud/projects/${stackit_resourcemanager_project.foundation.project_id}"
    service_account_email  = module.stackit_integration.service_account_email
    service_account_url    = "https://portal.stackit.cloud/service-accounts/${module.stackit_integration.service_account_email}/overview?project=${stackit_resourcemanager_project.foundation.project_id}"

    network_enabled            = local.network_enabled
    networked_landingzone_name = local.network_enabled ? module.stackit_integration.landingzone_refs["networked"].name : ""
    network_area_hub_uuid      = local.network_enabled ? meshstack_building_block.network_area_hub.metadata.uuid : ""
    network_area_id            = local.network_enabled ? local.network_area_id : ""
    network_area_url           = local.network_enabled ? "https://portal.stackit.cloud/network-area/network-areas/${local.network_area_id}/overview?organization=${var.stackit_org}" : ""
  })
}
