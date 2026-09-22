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

    # Phase 1 prints the instance URL in the instructions, so it needs a printable placeholder for
    # the window in which the Git building block has not reported it yet.
    forgejo_token_provided       = local.forgejo_token_provided
    forgejo_instance_url         = local.forgejo_instance_url
    forgejo_instance_url_display = coalesce(local.forgejo_instance_url, "the STACKIT Git instance (see the STACKIT Git building block for its URL)")
    forgejo_organization         = local.forgejo_organization
  })
}
