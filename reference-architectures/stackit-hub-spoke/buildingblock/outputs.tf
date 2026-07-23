output "lz_folder_container_id" {
  value       = module.foundation.lz_folder_container_id
  description = "Container ID of the STACKIT resourcemanager folder created for the landing zone. Tenant projects are created inside this folder."
}

output "backplane_project_id" {
  value       = module.foundation.backplane_project_id
  description = "Project ID of the STACKIT backplane project that hosts the service account used for tenant project creation."
}

output "backplane_project_url" {
  value       = module.foundation.backplane_project_url
  description = "Deep link to the backplane project in the STACKIT portal."
}

output "summary" {
  description = "Summary of the meshStack resources created by this reference architecture."
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    platform_identifier        = var.platform_identifier
    backplane_project_id       = module.foundation.backplane_project_id
    backplane_project_url      = module.foundation.backplane_project_url
    lz_folder_container_id     = module.foundation.lz_folder_container_id
    networked_landingzone_name = meshstack_landingzone.networked.metadata.name
    network_area_hub_uuid      = meshstack_building_block.network_area_hub.metadata.uuid
  })
}
