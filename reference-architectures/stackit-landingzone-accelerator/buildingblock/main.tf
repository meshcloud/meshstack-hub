locals {
  accelerator_inputs = provider::terraform::decode_tfvars(var.landing_zone_tfvars)

  # The provider reads a ref without a uuid as unknown, not as the shared runner.
  runner_ref = var.runner_ref.uuid == null ? null : var.runner_ref

  # The platform contract has a target per region and network area, all in one of these two folders.
  # Its keys are only known after apply, and a meshStack landing zone needs only the folder.
  landing_zone_folders = {
    public    = { folder = "landing_zones_public", description = "STACKIT projects in the public landing zone folder of the STACKIT Landing Zone Accelerator." }
    corporate = { folder = "landing_zones_corporate", description = "STACKIT projects in the corporate landing zone folder of the STACKIT Landing Zone Accelerator. They are not attached to its network area." }
  }

  landing_zones = {
    for key, lz in local.landing_zone_folders : key => {
      display_name        = "STACKIT ${title(key)}"
      description         = lz.description
      parent_container_id = module.accelerator.governance_folder_ids[lz.folder]
    } if contains(keys(local.accelerator_inputs.rm_folders), lz.folder)
  }
}

# An argument set to null replaces the accelerator's default, so an input the export leaves out
# gets that default spelled out: null or an empty collection.
module "accelerator" {
  source = "git::https://github.com/stackitcloud/stackit-landing-zone.git//src?ref=${var.accelerator_ref}"

  company_code    = local.accelerator_inputs.company_code
  company_name    = local.accelerator_inputs.company_name
  organization_id = local.accelerator_inputs.organization_id
  owner_email     = local.accelerator_inputs.owner_email
  region          = local.accelerator_inputs.region
  rm_folders      = local.accelerator_inputs.rm_folders

  audit_logs                      = lookup(local.accelerator_inputs, "audit_logs", null)
  connectivity                    = lookup(local.accelerator_inputs, "connectivity", null)
  connectivity_regions            = lookup(local.accelerator_inputs, "connectivity_regions", null)
  devops                          = lookup(local.accelerator_inputs, "devops", null)
  firewall_config                 = lookup(local.accelerator_inputs, "firewall_config", null)
  observability                   = lookup(local.accelerator_inputs, "observability", null)
  platform_contract_namespace     = lookup(local.accelerator_inputs, "platform_contract_namespace", null)
  rm_folder_parent_id             = lookup(local.accelerator_inputs, "rm_folder_parent_id", null)
  federated_identity_providers    = lookup(local.accelerator_inputs, "federated_identity_providers", [])
  labels                          = lookup(local.accelerator_inputs, "labels", {})
  landing_zone_namespace_services = lookup(local.accelerator_inputs, "landing_zone_namespace_services", {})
  landing_zones                   = lookup(local.accelerator_inputs, "landing_zones", {})
  organization_auditors           = lookup(local.accelerator_inputs, "organization_auditors", [])
  organization_owners             = lookup(local.accelerator_inputs, "organization_owners", [])
  platform_kubernetes             = lookup(local.accelerator_inputs, "platform_kubernetes", {})
  sandboxes                       = lookup(local.accelerator_inputs, "sandboxes", [])
}

module "stackit_integration" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit?ref=${var.hub.git_ref}"

  stackit_organization_id     = local.accelerator_inputs.organization_id
  stackit_project_owner_email = local.accelerator_inputs.owner_email
  stackit_project_id          = module.accelerator.management_project_id
  stackit_parent_container_id = local.accelerator_inputs.organization_id
  stackit_landing_zones       = local.landing_zones

  hub = var.hub

  meshstack = {
    owning_workspace_identifier = var.workspace
    runner_ref                  = local.runner_ref
    platform_identifier         = var.platform_identifier
  }
}
