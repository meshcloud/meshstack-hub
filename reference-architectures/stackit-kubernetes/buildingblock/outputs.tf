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

# TEMP (erstmal): git/dns/model-serving, the meshStack platform and the starterkit are disabled for
# the first run (project + SA + cluster only), so these outputs return null until re-enabled.
output "forgejo_url" {
  description = "URL of the STACKIT Git (Forgejo) instance hosting the application repositories."
  value       = null
}

output "dns_zone_name" {
  description = "DNS zone created for application ingress hostnames."
  value       = null
}

# output "platform_ref" {
#   description = "Reference to the meshStack SKE platform this architecture registered."
#   value       = meshstack_platform.ske.ref
# }

output "starterkit_bbd_uuid" {
  description = "UUID of the SKE Starterkit definition this architecture registered. Null until the Forgejo token is provided and the starterkit is registered on a later run."
  value       = null
}

output "summary" {
  description = "Summary of the resources created by this reference architecture."
  value       = <<-EOT
    # STACKIT Kubernetes Platform: **${local.platform_identifier}**

    %{~if var.playground_mode}
    > **Playground mode.** The platform identifier carries a random suffix so this deployment does not
    > occupy a name for good, and the hosting project and tenant are left destroyable. Do not publish
    > this platform or the building block definitions it registered to other workspaces. Redeploy with
    > `playground_mode` set to false for a platform that is actually used.
    %{~endif}

    > **First-run scope.** This run creates only the hosting project, the service account and the SKE
    > cluster. Platform services, Git, DNS, the meshStack platform and the starterkit are temporarily
    > disabled.

    ## Details

    | Property | Value |
    |----------|-------|
    | **Hosting Project** | [Open in STACKIT Portal](https://portal.stackit.cloud/projects/${local.stackit_project_id}) (`${local.stackit_project_id}`) |
    | **SKE Cluster** | `${var.cluster_name}` — @buildingblock[${meshstack_building_block.cluster.metadata.uuid}] |
  EOT
}
