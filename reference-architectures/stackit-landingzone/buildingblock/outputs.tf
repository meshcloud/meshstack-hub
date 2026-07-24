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

output "summary" {
  description = "Summary of the meshStack resources created by this reference architecture."
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    platform_identifier        = var.platform_identifier
    foundation_project_id      = stackit_resourcemanager_project.foundation.project_id
    foundation_project_url     = "https://portal.stackit.cloud/projects/${stackit_resourcemanager_project.foundation.project_id}"
    lz_folder_container_id     = stackit_resourcemanager_folder.this.container_id
    network_enabled            = local.network_enabled
    networked_landingzone_name = local.network_enabled ? meshstack_landingzone.networked[0].metadata.name : ""
    network_area_hub_uuid      = local.network_enabled ? meshstack_building_block.network_area_hub[0].metadata.uuid : ""
  })
}
