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

output "dns_zone_name" {
  value       = local.kubernetes_enabled ? module.dns_zone[0].zone_name : ""
  description = "DNS name of the shared zone every ordered cluster writes its own label into. Empty when the Kubernetes option is off."
}

output "ai_gateway_url" {
  value       = local.ai_enabled ? jsondecode(meshstack_building_block.ai_platform[0].status.outputs["litellm_url"].value) : ""
  description = "URL of the LiteLLM gateway the AI platform published on the cluster's application domain. Empty when the AI option is off."
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
    network_area_hub_uuid      = local.network_enabled ? meshstack_building_block.network_area_hub[0].metadata.uuid : ""
    network_area_id            = local.network_enabled ? local.network_area_id : ""
    network_area_url           = local.network_enabled ? "https://portal.stackit.cloud/network-area/network-areas/${local.network_area_id}/overview?organization=${var.stackit_org}" : ""

    # No value below carries a credential, and none is read from `var.ai`, which is sensitive: the
    # summary is a plain-text building block output and would turn sensitive as a whole.
    kubernetes_enabled = local.kubernetes_enabled
    dns_zone_name      = local.kubernetes_enabled ? module.dns_zone[0].zone_name : ""
    dns_zone_url       = local.kubernetes_enabled ? "https://portal.stackit.cloud/projects/${local.dns_zone_project_id}/dns" : ""
    dns_zone_label     = local.kubernetes_enabled && var.kubernetes.dns_cluster_label_enabled

    ai_enabled     = local.ai_enabled
    ai_platform_bb = local.ai_enabled ? meshstack_building_block.ai_platform[0].metadata.uuid : ""
    ai_gateway_url = local.ai_enabled ? jsondecode(meshstack_building_block.ai_platform[0].status.outputs["litellm_url"].value) : ""
  })
}
