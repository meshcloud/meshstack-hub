# meshStack has no timer that deletes a building block. So the backplane orders one building block of
# its own, the sweeper, whose definition runs daily and deletes every expired access block. That uses
# meshStack's own scheduler and needs no infrastructure outside meshStack. See ./README.md.

# meshStack requires an expiry on every API key and caps how far out it may sit. Rotating at half the
# lifetime means any apply in that window rolls the expiry forward, with no diff in between.
resource "time_rotating" "api_key" {
  rotation_days = floor(var.api_key_lifetime_days / 2)
}

# A run's ephemeral token only reaches its own workspace, and the access blocks live in every
# workspace that ordered one, so the sweeper needs an admin-scoped key.
resource "meshstack_api_key" "sweeper" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
  }

  spec = {
    display_name = "${var.display_name} sweeper"
    permissions = [
      # Lists the blocks of a definition this workspace owns, in every workspace.
      "MANAGED_BUILDINGBLOCK_LIST",
      # meshStack has no MANAGED_ scope for deleting a building block.
      "ADM_BUILDINGBLOCK_DELETE",
    ]
    expires_at = formatdate("YYYY-MM-DD", timeadd(time_rotating.api_key.rfc3339, "${var.api_key_lifetime_days * 24}h"))
  }
}

resource "meshstack_building_block_definition" "sweeper" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name = "${var.display_name} sweeper"
    description  = "Deletes the building blocks of ${var.display_name} whose duration has passed. Platform team automation, not for ordering."
    target_type  = "WORKSPACE_LEVEL"
    symbol       = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/meshstack/temporary-group-access/buildingblock/logo.png"

    schedule = {
      mode               = "DRIFT_RECONCILIATION"
      frequency          = "DAILY"
      automatic_approval = true
    }

    readme = chomp(<<-EOT
      Deletes every building block of ${var.display_name} whose duration has passed. The platform team
      operates one instance of it in its own workspace; it runs once a day.

      ## 🎯 When to use it

      Do not order it. The backplane of ${var.display_name} creates the one instance it needs.

      ## 💡 Usage examples

      **Example 1: See what was deleted**
      Open the runs of the sweeper building block in the platform team's workspace. Each run's summary
      lists the access blocks it deleted.

      ## 📊 Shared Responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Keep the sweeper's API key valid by re-applying the backplane | ✅ | ❌ |
      | Investigate a sweeper run that failed | ✅ | ❌ |
      | Order temporary group access | ❌ | ✅ |
      EOT
    )
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    runner_ref    = var.meshstack.runner_ref
    deletion_mode = "DELETE"

    implementation = {
      terraform = {
        terraform_version              = "1.12.5"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/meshstack/temporary-group-access/backplane/sweeper"
        ref_name                       = var.hub.git_ref
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      MESHSTACK_API_KEY = {
        display_name    = "MESHSTACK_API_KEY"
        description     = "Client id of the sweeper's admin-scoped API key, which the meshStack provider and the delete script read from the environment."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(meshstack_api_key.sweeper.status.client_id)
      }

      MESHSTACK_API_SECRET = {
        display_name    = "MESHSTACK_API_SECRET"
        description     = "Client secret paired with MESHSTACK_API_KEY."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        sensitive = {
          argument = {
            secret_value   = meshstack_api_key.sweeper.status.client_secret
            secret_version = nonsensitive(sha256(meshstack_api_key.sweeper.status.client_secret))
          }
        }
      }

      building_block_definition_uuid = {
        display_name    = "Access Definition UUID"
        description     = "UUID of the definition whose expired building blocks are deleted."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.building_block_definition_uuid)
      }
    }

    outputs = {
      summary = {
        display_name    = "Summary"
        type            = "STRING"
        assignment_type = "SUMMARY"
      }
    }
  }
}

resource "meshstack_building_block" "sweeper" {
  spec = {
    building_block_definition_version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.sweeper.version_latest : meshstack_building_block_definition.sweeper.version_latest_release

    display_name = "${var.display_name} sweeper"
    target_ref = {
      kind = "meshWorkspace"
      name = var.meshstack.owning_workspace_identifier
    }

    inputs = {}
  }

  lifecycle {
    postcondition {
      condition     = self.status.succeeded
      error_message = "Building block ${self.metadata.uuid} did not succeed (health status ${self.status.health_status}, action ${self.status.action}). See its run in meshPanel."
    }
  }
}
