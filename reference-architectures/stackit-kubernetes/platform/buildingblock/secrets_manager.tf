module "secrets_manager_integration" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/secrets-manager?ref=${var.hub.git_ref}"

  approval_policies = var.approval_policies

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = local.platform_hub
}

resource "meshstack_building_block" "secrets_manager" {
  wait_for_completion = true

  lifecycle {
    postcondition {
      condition     = self.status.succeeded
      error_message = "Building block ${self.metadata.uuid} did not succeed (health status ${self.status.health_status}, action ${self.status.action}). See its run in meshPanel."
    }
  }

  spec = {
    parent_building_block_refs            = [meshstack_building_block.platform_federation.ref]
    building_block_definition_version_ref = module.secrets_manager_integration.building_block_definition.version_ref
    display_name                          = "Secrets Manager"
    target_ref                            = local.tenant_ref

    inputs = merge(
      {
        instance_name                 = { value = jsonencode(var.platform_identifier) }
        STACKIT_SERVICE_ACCOUNT_EMAIL = { value = jsonencode(local.service_account_email) }
        release_on_destroy            = { value = jsonencode(local.imports.secrets_manager != null && var.playground_mode) }
      },
      local.imports.secrets_manager == null ? {} : {
        imports = { value = jsonencode(jsonencode(local.imports.secrets_manager)) }
      },
    )
  }
}

# The instance never changes for the platform's life, and a definition update would otherwise make
# its id unknown for one plan, rerunning every child that writes to it.
resource "terraform_data" "secrets_manager_instance_id" {
  input = jsondecode(meshstack_building_block.secrets_manager.status.outputs["instance_id"].value)

  lifecycle {
    ignore_changes = [input]
  }
}

# TODO: replacing a user deletes the old one, so blocks on an older definition version fail.
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
