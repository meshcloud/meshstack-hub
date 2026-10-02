output "lz_folder_container_id" {
  value       = local.deployed.lz_folder_container_id
  description = "Container ID of the STACKIT resourcemanager folder created for the landing zone. Tenant projects are created inside this folder."
}

output "foundation_project_id" {
  value       = local.deployed.foundation_project_id
  description = "Project ID of the STACKIT foundation project that hosts the landing-zone core assets (the service account used for tenant project creation)."
}

output "foundation_project_url" {
  value       = local.deployed.foundation_project_url
  description = "Deep link to the foundation project in the STACKIT portal."
}

locals {
  # A bootstrap run created nothing, so every attribute below is null. The template reads them only
  # in its deploy branch, but templatefile rejects a null in the map it is handed either way.
  deployed = {
    platform_identifier    = local.platform_identifier
    lz_folder_container_id = local.deploy ? stackit_resourcemanager_folder.this.container_id : ""
    lz_folder_url          = local.deploy ? "https://portal.stackit.cloud/dashboard?organization=${var.stackit_org}&folder=${stackit_resourcemanager_folder.this.folder_id}" : ""
    foundation_project_id  = local.deploy ? stackit_resourcemanager_project.foundation.project_id : ""
    foundation_project_url = local.deploy ? "https://portal.stackit.cloud/projects/${stackit_resourcemanager_project.foundation.project_id}" : ""
    service_account_email  = local.deploy ? module.stackit_integration.service_account_email : ""
    service_account_url    = local.deploy ? "https://portal.stackit.cloud/service-accounts/${module.stackit_integration.service_account_email}/overview?project=${stackit_resourcemanager_project.foundation.project_id}" : ""

    networked_landingzone_name = local.network_enabled ? module.stackit_integration.landingzone_refs["networked"].name : ""
    network_area_hub_uuid      = local.network_enabled ? meshstack_building_block.network_area_hub.metadata.uuid : ""
    network_area_id            = local.network_enabled ? local.network_area_id : ""
    network_area_url           = local.network_enabled ? "https://portal.stackit.cloud/network-area/network-areas/${local.network_area_id}/overview?organization=${var.stackit_org}" : ""

    platform_ref                                = local.deploy ? module.stackit_integration.platform_ref : { uuid = "", kind = "" }
    landingzone_refs                            = local.deploy ? module.stackit_integration.landingzone_refs : {}
    service_account_bbd_version_uuid            = try(module.service_account_integration.building_block_definition.version_ref_release.uuid, "")
    service_account_federation_bbd_version_uuid = try(module.service_account_federation_integration.building_block_definition.version_ref_release.uuid, "")
  }
}

output "summary" {
  description = "Summary of the meshStack resources created by this reference architecture."

  precondition {
    condition     = local.own_definition != null
    error_message = "No building block definition named \"${var.bbd_display_name}\" in workspace ${var.workspace}, so the WIF claims to trust cannot be resolved. The `bbd_display_name` input must match the definition's display name."
  }

  value = templatefile("${path.module}/SUMMARY.md.tftpl", merge(local.deployed, {
    deploy          = local.deploy
    playground_mode = var.playground_mode

    wif_issuer   = local.wif.issuer
    wif_audience = local.wif.audience
    wif_subject  = local.wif.subject

    organization_id  = var.stackit_org
    organization_url = "https://portal.stackit.cloud/dashboard?organization=${var.stackit_org}"
    network_enabled  = local.network_enabled
  }))
}
