output "root_folder_container_id" {
  value       = stackit_resourcemanager_folder.root.container_id
  description = "Container ID of the root folder that holds every folder of the accelerator."
}

output "management_project_id" {
  value       = module.accelerator.management_project_id
  description = "Project ID of the accelerator's management project, which also holds the service account of the STACKIT Project definition."
}

output "management_project_url" {
  value       = "https://portal.stackit.cloud/dashboard?project=${module.accelerator.management_project_id}"
  description = "Deep link to the management project in the STACKIT portal."
}

output "platform_contract" {
  value       = jsonencode(module.accelerator.platform_contract)
  description = "The accelerator's platform contract as JSON: one target per landing zone of the meshStack platform."
}

output "summary" {
  description = "Summary of the foundation and the meshStack platform this reference architecture created."
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    organization_id        = local.accelerator_inputs.organization_id
    organization_url       = "https://portal.stackit.cloud/dashboard?organization=${local.accelerator_inputs.organization_id}"
    root_folder_name       = stackit_resourcemanager_folder.root.name
    root_folder_id         = stackit_resourcemanager_folder.root.container_id
    root_folder_url        = "https://portal.stackit.cloud/dashboard?organization=${local.accelerator_inputs.organization_id}&folder=${stackit_resourcemanager_folder.root.folder_id}"
    management_project_id  = module.accelerator.management_project_id
    management_project_url = "https://portal.stackit.cloud/dashboard?project=${module.accelerator.management_project_id}"
    service_account_email  = module.stackit_integration.service_account_email
    platform_identifier    = local.platform_identifier
    playground_mode        = var.playground_mode
    network_areas = merge(
      module.accelerator.connectivity_network_area_ids_by_area,
      module.accelerator.connectivity_network_area_ids_by_region.eu01,
      module.accelerator.connectivity_network_area_ids_by_region.eu02,
    )
    display_name      = local.display_name
    landing_zone_tags = var.tags.landingzone
    landing_zones = {
      for key, lz in local.landing_zones : "${local.platform_identifier}-${key}" => {
        display_name = lz.display_name
        folder       = lz.parent_container_id
      }
    }
  })
}
