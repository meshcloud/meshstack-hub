output "summary" {
  description = "Summary of the resources created by the STACKIT Kubernetes Platform."
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    platform_identifier = var.platform_identifier
    playground_mode     = var.playground_mode

    stackit_project_id          = var.stackit_project_id
    secrets_manager_instance_id = local.secrets_manager_instance_id
    cluster_name                = var.cluster_name
    cluster_bb_uuid             = meshstack_building_block.cluster.metadata.uuid
    service_account_bb_uuid     = meshstack_building_block.service_account.metadata.uuid
    kubernetes_platform_bb_uuid = meshstack_building_block.kubernetes_platform.metadata.uuid
    ingress_bb_uuid             = meshstack_building_block.ingress.metadata.uuid
    git_bb_uuid                 = meshstack_building_block.git.metadata.uuid

    container_registry_bb_uuid = meshstack_building_block.container_registry.metadata.uuid
    registry_name              = local.registry_name
    registry_host              = local.registry_host
    registry_url               = jsondecode(meshstack_building_block.container_registry.status.outputs["registry_url"].value)
    registry_robot_url         = jsondecode(meshstack_building_block.container_registry.status.outputs["registry_robot_url"].value)

    forgejo_instance_url = local.forgejo_instance_url
    forgejo_organization = local.forgejo_organization

    stage_names                    = join(", ", [for stage in sort(keys(var.stages)) : "**${stage}**"])
    dns_zone_name                  = local.dns_zone_name
    dns_bb_uuid                    = meshstack_building_block.dns.metadata.uuid
    ai_bb_uuid                     = meshstack_building_block.ai_llm.metadata.uuid
    ai_model                       = var.ai_model
    harbor_robot_linked            = local.harbor_robot_linked
    platform_service_account_email = local.service_account_email
    platform_service_account_id    = var.automation_identity.service_account_id
  })
}
