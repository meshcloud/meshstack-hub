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

    ## Details

    | Property | Value |
    |----------|-------|
    | **Hosting Project** | [Open in STACKIT Portal](https://portal.stackit.cloud/projects/${local.stackit_project_id}) (`${local.stackit_project_id}`) |
    | **SKE Cluster** | `${var.cluster_name}` — @buildingblock[${meshstack_building_block.cluster.metadata.uuid}] |
    | **Platform Services** | @buildingblock[${meshstack_building_block.platform_services.metadata.uuid}] |
    | **meshStack Platform** | `${local.platform_identifier}` |

    ## What application teams get

    The **${local.platform_identifier}** platform is published with a **dev** and a **prod** landing
    zone. Application teams request a Kubernetes namespace on SKE by ordering a tenant in either
    landing zone from the self-service catalog.
  EOT
}
