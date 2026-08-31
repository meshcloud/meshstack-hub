variable "api_key_grantable_permissions" {
  type = list(string)
  default = [
    "APIKEY_LIST",
    "PROJECT_LIST",
    "TENANT_LIST",
    "LANDINGZONE_LIST",
    "PAYMENTMETHOD_LIST",
  ]
  nullable    = false
  description = <<-EOT
  Catalog of workspace permissions the platform team allows keys minted by this building block to
  carry. It drives two things at once: it is granted to the run's ephemeral token (so the run can
  actually issue a key holding any of these), and it is offered to the ordering user as the
  selectable set. Users pick a subset; nothing outside this list can ever be granted.
  See https://docs.meshcloud.io/api/authentication/api-permissions/ for available values.
  EOT

  validation {
    condition     = length(var.api_key_grantable_permissions) > 0
    error_message = "At least one grantable permission must be configured."
  }
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    tags                        = optional(map(list(string)), {})
  })
  description = "Shared meshStack context. Tags are optional and propagated to building block definition metadata."
  default = {
    owning_workspace_identifier = "flori-land"
    # tags = {
    #   team = ["platform"]
    # }
  }
}

variable "hub" {
  type = object({
    git_ref   = optional(string, "main")
    bbd_draft = optional(bool, true)
  })
  const = true
  default = {
    git_ref   = "feature/api-keys"
    bbd_draft = true
  }
  description = <<-EOT
  `git_ref`: Hub release reference. Set to a tag (e.g. 'v1.2.3') or branch or commit sha of the meshstack-hub repo.
  `bbd_draft`: If true, the building block definition version is kept in draft mode.
  EOT
}

output "building_block_definition" {
  description = "BBD is consumed in building block compositions."
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  }
}

locals {
  # The run token needs APIKEY_SAVE to mint a key at all, plus every permission the key may carry so
  # any user-selected subset can be issued without exceeding the token's own grants.
  run_token_permissions = toset(concat(["APIKEY_SAVE"], var.api_key_grantable_permissions))
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name     = "meshStack API Key"
    symbol           = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/meshstack/api-key/buildingblock/logo.png"
    description      = "Issues a workspace-scoped meshStack API key with a chosen set of permissions and an optional expiry."
    target_type      = "WORKSPACE_LEVEL"
    run_transparency = true

    readme = chomp(<<-EOT
    Issues a meshStack API key scoped to a workspace, granting a subset of permissions the platform
    team has made available and, optionally, an expiry date. The generated client ID and client
    secret are returned so automation can authenticate against the meshStack API.

    ## 🎯 When to use it

    Order this building block when you:
    - Need programmatic access to the meshStack API from CI pipelines, scripts or integrations.
    - Want a key scoped to exactly the permissions a job needs, rather than reusing a personal token.
    - Want the key to expire on its own instead of living forever.

    ## 💡 Usage examples

    **Example 1: CI read-only key**
    A team orders a key named `ci-read` with `PROJECT_LIST` and `TENANT_LIST` so their pipeline can
    enumerate projects and tenants without any write access.

    **Example 2: Time-boxed integration key**
    A team wires a third-party tool to meshStack with a key that expires at the end of the quarter,
    so access lapses automatically when the evaluation ends.

    ## 🔑 Retrieving the credentials

    After the run completes, the **Client ID** is shown as an output and the **Client Secret** is
    returned as a sensitive output. Store the secret securely — it authenticates as the key.

    ## 📊 Shared Responsibility

    | Responsibility | Platform Team | Application Team |
    |---|:---:|:---:|
    | Decide which permissions may be granted (the grantable catalog) | ✅ | ❌ |
    | Order the key and pick its name, permissions and expiry | ❌ | ✅ |
    | Store the client secret securely and rotate it as needed | ❌ | ✅ |
    | Delete the key (destroy the building block) when no longer needed | ❌ | ✅ |
    EOT
    )
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"

    implementation = {
      terraform = {
        terraform_version              = "1.12.5"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/meshstack/api-key/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    # The run's ephemeral token gets exactly these: APIKEY_SAVE to mint the key, plus the grantable
    # catalog so any subset the user selects can be issued.
    permissions = local.run_token_permissions

    inputs = {
      owned_by_workspace = {
        display_name    = "Owning Workspace"
        description     = "Identifier of the workspace that owns the API key."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        display_order   = 1
      }

      display_name = {
        display_name    = "Key Name"
        description     = "Human-readable name of the API key."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("workspace-api-key")
        display_order   = 2
      }

      permissions = {
        display_name      = "Permissions"
        description       = "Permissions granted to the API key. Pick a subset of what the platform team has made grantable."
        type              = "MULTI_SELECT"
        assignment_type   = "USER_INPUT"
        selectable_values = var.api_key_grantable_permissions
        display_order     = 3
      }

      expires_at = {
        display_name    = "Expiry Date"
        description     = "Optional ISO date (e.g. 2025-12-31) after which the key stops working. Leave empty for a key that never expires."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("")
        display_order   = 4
      }
    }

    outputs = {
      client_id = {
        display_name    = "Client ID"
        type            = "STRING"
        assignment_type = "NONE"
      }

      client_secret = {
        display_name    = "Client Secret"
        type            = "STRING"
        assignment_type = "NONE"
      }

      uuid = {
        display_name    = "API Key UUID"
        type            = "STRING"
        assignment_type = "NONE"
      }
    }
  }
}

terraform {
  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.24.0"
    }
  }
}
