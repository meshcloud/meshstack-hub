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

output "starterkit_bbd_version_uuid" {
  value       = module.stackit_project_starterkit.building_block_definition.version_ref.uuid
  description = "Version uuid of the STACKIT Project Starterkit definition this architecture registered. The definition is created inside this run, so it cannot be reached through a module output. Do not use it to order starterkit instances as code: the starterkit deletes itself at the end of its run, so an as-code order never converges and creates another project on every apply."
}

output "summary" {
  description = "Summary of the meshStack resources created by this reference architecture."
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    platform_identifier    = var.platform_identifier
    organization_id        = var.stackit_org
    organization_url       = "https://portal.stackit.cloud/dashboard?organization=${var.stackit_org}"
    lz_folder_container_id = stackit_resourcemanager_folder.this.container_id
    lz_folder_url          = "https://portal.stackit.cloud/dashboard?organization=${var.stackit_org}&folder=${stackit_resourcemanager_folder.this.folder_id}"
    foundation_project_id  = stackit_resourcemanager_project.foundation.project_id
    foundation_project_url = "https://portal.stackit.cloud/projects/${stackit_resourcemanager_project.foundation.project_id}"
    service_account_email  = module.stackit_integration.service_account_email
    service_account_url    = "https://portal.stackit.cloud/service-accounts/${module.stackit_integration.service_account_email}/overview?project=${stackit_resourcemanager_project.foundation.project_id}"

    network_enabled            = local.network_enabled
    networked_landingzone_name = local.network_enabled ? module.stackit_integration.landingzone_names["networked"] : ""
    network_area_hub_uuid      = local.network_enabled ? meshstack_building_block.network_area_hub.metadata.uuid : ""
    network_area_id            = local.network_enabled ? local.network_area_id : ""
    network_area_url           = local.network_enabled ? "https://portal.stackit.cloud/network-area/network-areas/${local.network_area_id}/overview?organization=${var.stackit_org}" : ""
  })
}
