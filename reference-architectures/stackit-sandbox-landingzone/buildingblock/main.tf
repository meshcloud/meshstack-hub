resource "meshstack_location" "this" {
  count = var.use_global_location ? 0 : 1

  metadata = {
    name               = var.platform_identifier
    owned_by_workspace = var.workspace
  }

  spec = {
    display_name = var.platform_identifier
    description  = "STACKIT sandbox location created by the STACKIT Sandbox Landing Zone."
  }
}

resource "stackit_resourcemanager_folder" "this" {
  name                = var.platform_identifier
  owner_email         = var.stackit_owner_email
  parent_container_id = var.stackit_org
}

# Project hosting the backplane service account that creates tenant projects.
# Created directly under the organization (not the landing-zone folder).
resource "stackit_resourcemanager_project" "backplane" {
  name                = "${var.platform_identifier}-backplane"
  owner_email         = var.stackit_owner_email
  parent_container_id = var.stackit_org
}

module "stackit_integration" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit?ref=${var.git_ref}"

  stackit_organization_id                 = var.stackit_org
  stackit_parent_container_id             = stackit_resourcemanager_folder.this.container_id
  stackit_project_id                      = stackit_resourcemanager_project.backplane.project_id
  stackit_service_account_name            = substr(var.platform_identifier, 0, 20)
  role_mapping                            = var.role_mapping
  stackit_organization_onboarding_enabled = var.stackit_organization_onboarding_enabled
  stackit_network_area_tag_name           = var.network_area_tag_name

  hub = {
    git_ref = var.git_ref
  }

  meshstack = {
    owning_workspace_identifier = var.workspace
    location_name               = var.use_global_location ? "global" : meshstack_location.this[0].metadata.name
    platform_identifier         = var.platform_identifier
    tags                        = var.tags
  }
}
