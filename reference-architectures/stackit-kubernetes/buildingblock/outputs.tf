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

output "forgejo_url" {
  description = "URL of the STACKIT Git (Forgejo) instance hosting the application repositories."
  value       = local.forgejo_base_url
}

output "dns_zone_name" {
  description = "DNS zone created for application ingress hostnames."
  value       = stackit_dns_zone.this.dns_name
}

output "platform_ref" {
  description = "Reference to the meshStack SKE platform this architecture registered."
  value       = meshstack_platform.ske.ref
}

# The starterkit definition is created inside this run, so it cannot be reached through a module
# output for as-code ordering. Exposed for reference only; the starterkit deletes itself at the end
# of its run, so an as-code order never converges.
output "starterkit_bbd_uuid" {
  description = "UUID of the SKE Starterkit definition this architecture registered. Null until the Forgejo token is provided and the starterkit is registered on a later run."
  value       = local.starterkit_bbd_uuid
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
    | **Git (Forgejo)** | [${local.forgejo_base_url}](${local.forgejo_base_url}) — organization `${var.forgejo_organization}` |
    | **Ingress DNS Zone** | `${stackit_dns_zone.this.dns_name}` |
    | **Starterkit Definition** | ${coalesce(local.starterkit_bbd_uuid, "_not yet registered — provide the Forgejo token and re-run_")} |

    ## What application teams get

    Application teams order the **SKE Starterkit** from the self-service catalog. Each order provisions
    a dev and a prod meshProject with a dedicated SKE namespace, a Forgejo Git repository wired to a
    Forgejo Actions CI/CD pipeline, and access to STACKIT Model Serving for the sample application.
  EOT
}
