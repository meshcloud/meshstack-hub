output "hosting_project_id" {
  description = "STACKIT project id the SKE cluster and its assets run in (self-hosted meshStack tenant)."
  value       = local.stackit_project_id
}

output "hosting_project_url" {
  description = "Deep link to the hosting project in the STACKIT portal."
  value       = "https://portal.stackit.cloud/projects/${local.stackit_project_id}"
}

output "cluster_building_block_uuid" {
  description = "UUID of the SKE Cluster building block this architecture ordered."
  value       = meshstack_building_block.cluster.metadata.uuid
}

output "platform_ref" {
  description = "Reference to the meshStack SKE platform this architecture registered."
  value       = meshstack_platform.ske.ref
}

output "forgejo_instance_url" {
  description = "URL of the STACKIT Git (Forgejo) instance this architecture created. Sign in here to mint the token the second phase needs."
  value       = local.forgejo_instance_url
}

output "forgejo_organization" {
  description = "Forgejo organization application repositories are created in, or null while no token has been supplied."
  value       = local.forgejo_organization
}

output "summary" {
  description = "Summary of the resources created by this reference architecture."
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    platform_identifier = local.platform_identifier
    playground_mode     = var.playground_mode

    stackit_project_id        = local.stackit_project_id
    cluster_name              = var.cluster_name
    cluster_bb_uuid           = meshstack_building_block.cluster.metadata.uuid
    platform_services_bb_uuid = meshstack_building_block.platform_services.metadata.uuid
    git_bb_uuid               = meshstack_building_block.git.metadata.uuid

    # Phase 1 prints the instance URL in the instructions, so it needs a printable placeholder for
    # the window in which the Git building block has not reported it yet.
    forgejo_token_provided       = local.forgejo_token_provided
    forgejo_instance_url         = local.forgejo_instance_url
    forgejo_instance_url_display = coalesce(local.forgejo_instance_url, "the STACKIT Git instance (see the STACKIT Git building block for its URL)")
    forgejo_organization         = local.forgejo_organization
    harbor_configured            = nonsensitive(var.harbor_username != null && var.harbor_username != "")
  })
}
