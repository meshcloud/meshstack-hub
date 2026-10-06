module "secrets_manager_integration" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/secrets-manager?ref=${var.hub.git_ref}"

  approval_policies = var.approval_policies

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub
}

resource "meshstack_building_block" "secrets_manager" {
  wait_for_completion = true

  lifecycle {
    postcondition {
      condition     = self.status.status == "SUCCEEDED"
      error_message = "Building block ${self.metadata.uuid} is ${self.status.status}, not SUCCEEDED. See its run in meshPanel."
    }
  }

  spec = {
    parent_building_block_refs            = [meshstack_building_block.platform_federation.ref]
    building_block_definition_version_ref = module.secrets_manager_integration.building_block_definition.version_ref
    display_name                          = "Secrets Manager"
    target_ref                            = local.tenant_ref

    inputs = {
      instance_name                 = { value = jsonencode(var.platform_identifier) }
      STACKIT_SERVICE_ACCOUNT_EMAIL = { value = jsonencode(local.service_account_email) }
    }
  }
}

# The instance belongs to this platform alone, so one writer and one reader for all its building
# blocks are enough.
#
# TODO: replacing either user, for example by changing its description, deletes the old one.
# Building blocks on an older definition version still hold the old credentials and fail on their
# next run.
resource "stackit_secretsmanager_user" "writer" {
  project_id    = var.stackit_project_id
  instance_id   = local.secrets_manager_instance_id
  description   = "${var.platform_identifier} writer"
  write_enabled = true
}

resource "stackit_secretsmanager_user" "reader" {
  project_id    = var.stackit_project_id
  instance_id   = local.secrets_manager_instance_id
  description   = "${var.platform_identifier} reader"
  write_enabled = false
}
