locals {
  accelerator_inputs = provider::terraform::decode_tfvars(var.landing_zone_tfvars)

  # The provider reads a ref without a uuid as unknown, not as the shared runner.
  runner_ref = var.runner_ref.uuid == null ? null : var.runner_ref

  # The identifier is unique across the whole meshStack instance and lands in every landing zone
  # name, so a playground deployment suffixes it and leaves the plain name free.
  platform_identifier = var.playground_mode ? "${var.platform_identifier}-${random_string.playground_suffix.result}" : var.platform_identifier
  display_name        = var.playground_mode ? "STACKIT Project (${local.platform_identifier})" : "STACKIT Project"

  # The meshPanel Tags form sends each tag map as a list of {key, values} entries.
  tags = {
    landingzone    = { for e in var.tags.landingzone : e.key => e.values }
    building_block = { for e in var.tags.building_block : e.key => e.values }
  }

  # meshStack landing zone identifiers are lowercase alphanumerics joined by single dashes.
  landing_zones = {
    for key, lz in lookup(local.accelerator_inputs, "landing_zones", {}) : trim(replace(lower(key), "/[^a-z0-9]+/", "-"), "-") => {
      display_name        = "${lz.project_name} (${lookup(lz, "corporate", true) ? "corporate" : "public"})"
      description         = lookup(lz, "corporate", true) ? "STACKIT projects in the corporate landing zone folder of the STACKIT Landing Zone Accelerator. They are not attached to its network area." : "STACKIT projects in the public landing zone folder of the STACKIT Landing Zone Accelerator."
      parent_container_id = module.accelerator.governance_folder_ids[lookup(lz, "corporate", true) ? "landing_zones_corporate" : "landing_zones_public"]
    }
  }
}

# Flipping the flag on an existing platform would rename the platform and every landing zone.
resource "terraform_data" "playground_mode" {
  input = var.playground_mode

  lifecycle {
    ignore_changes = [input]

    postcondition {
      condition     = self.output == var.playground_mode
      error_message = "playground_mode cannot change after the order."
    }
  }
}

resource "random_string" "playground_suffix" {
  lifecycle {
    enabled = var.playground_mode
  }

  length  = 6
  special = false
  upper   = false
}

# Holds every folder of the accelerator, whose folder names must be unique in their parent.
resource "stackit_resourcemanager_folder" "root" {
  name                = var.playground_mode ? "playground-${local.platform_identifier}" : local.platform_identifier
  owner_email         = local.accelerator_inputs.owner_email
  parent_container_id = coalesce(lookup(local.accelerator_inputs, "rm_folder_parent_id", null), local.accelerator_inputs.organization_id)
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

  rm_folder_parent_id = stackit_resourcemanager_folder.root.container_id

  audit_logs                      = lookup(local.accelerator_inputs, "audit_logs", null)
  connectivity                    = lookup(local.accelerator_inputs, "connectivity", null)
  connectivity_regions            = lookup(local.accelerator_inputs, "connectivity_regions", null)
  devops                          = lookup(local.accelerator_inputs, "devops", null)
  firewall_config                 = lookup(local.accelerator_inputs, "firewall_config", null)
  observability                   = lookup(local.accelerator_inputs, "observability", null)
  platform_contract_namespace     = lookup(local.accelerator_inputs, "platform_contract_namespace", null)
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

  platform_display_name = local.display_name
  bbd_display_name      = local.display_name
  hub                   = var.hub

  meshstack = {
    owning_workspace_identifier = var.workspace
    runner_ref                  = local.runner_ref
    platform_identifier         = local.platform_identifier
    tags                        = local.tags
  }
}
