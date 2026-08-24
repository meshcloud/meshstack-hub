locals {
  # Populated once the tenant has replicated, which is what the STACKIT Project building block inside
  # the tenant produces. `try` keeps the run from failing if this output is read before then.
  stackit_project_id = try(meshstack_tenant.this.spec.platform_tenant_id, null)

  # A child building block's outputs arrive JSON-encoded, same as this block's own.
  network_cidr = local.network_enabled ? try(jsondecode(meshstack_building_block.network.status.outputs["network_cidr"].value), null) : null
}

output "project_identifier" {
  description = "Identifier of the created meshProject, which is also the name of its STACKIT project."
  value       = meshstack_project.this.metadata.name
}

output "stackit_project_url" {
  description = "Deep link to the created STACKIT project, once the tenant has replicated."
  value       = local.stackit_project_id == null ? "https://portal.stackit.cloud" : "https://portal.stackit.cloud/projects/${local.stackit_project_id}"
}

# `n/a` rather than null when there is no network. A declared building block definition output has to
# be produced on every run: returning null fails the run at the meshStack Validation step with
#   Output 'network_cidr' was expected but not provided
# which loses a run that did everything else correctly, and reads like a missing output rather than an
# empty one. A visible placeholder beats an empty string in the panel.
output "network_cidr" {
  description = "IPv4 CIDR of the spoke network created inside the project, or `n/a` when the landing zone has no network area."
  value       = coalesce(local.network_cidr, "n/a")
}

output "summary" {
  description = "Summary of what the starterkit created."
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    project_display_name = var.name
    project_identifier   = meshstack_project.this.metadata.name
    landing_zone         = var.landing_zone
    landing_zone_name    = local.landing_zone_ref.name

    network = (local.network_enabled
      ? "@buildingblock[${meshstack_building_block.network.metadata.uuid}]${local.network_cidr == null ? "" : " — `${local.network_cidr}`"}"
      : "none — the `${var.landing_zone}` landing zone is not attached to a network area"
    )
    stackit_project = (local.stackit_project_id == null
      ? "provisioning — the STACKIT Project building block is still running"
      : "[Open in STACKIT Portal](https://portal.stackit.cloud/projects/${local.stackit_project_id}) (`${local.stackit_project_id}`)"
    )
    project_admin = local.creator_is_user ? var.creator.displayName : "not assigned — the creator is a ${var.creator.type}, which has no user to bind"
  })
}
