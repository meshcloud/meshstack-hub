output "ske_project_url" {
  description = "Deep link to the STACKIT project the SKE cluster and its assets run in."
  value       = "https://portal.stackit.cloud/projects/${local.stackit_project_id}"
}

output "summary" {
  description = "Summary of the resources created by this reference architecture."
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    platform_identifier = local.platform_identifier
    playground_mode     = var.playground_mode

    stackit_project_id          = local.stackit_project_id
    cluster_name                = local.cluster_name
    cluster_bb_uuid             = meshstack_building_block.cluster.metadata.uuid
    kubernetes_platform_bb_uuid = meshstack_building_block.kubernetes_platform.metadata.uuid
    ingress_bb_uuid             = meshstack_building_block.ingress.metadata.uuid
    git_bb_uuid                 = meshstack_building_block.git.metadata.uuid

    container_registry_bb_uuid = meshstack_building_block.container_registry.metadata.uuid
    registry_name              = local.registry_name
    registry_host              = local.registry_host
    registry_url               = local.registry_url
    registry_robot_url         = local.registry_robot_url

    forgejo_instance_url = local.forgejo_instance_url
    forgejo_organization = local.forgejo_organization

    stage_names                    = join(", ", [for stage in sort(keys(var.stages)) : "**${stage}**"])
    dns_zone_name                  = local.dns_zone_name
    dns_bb_uuid                    = meshstack_building_block.dns.metadata.uuid
    ai_bb_uuid                     = meshstack_building_block.ai_llm.metadata.uuid
    ai_model                       = var.ai_model
    phase2_completed               = local.phase2_completed
    platform_service_account_email = local.platform_service_account_email
    platform_service_account_id    = local.platform_service_account_id
  })
}
