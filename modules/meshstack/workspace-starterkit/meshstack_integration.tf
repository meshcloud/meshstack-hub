variable "platform_uuid" {
  type        = string
  nullable    = false
  description = "UUID of the meshPlatform the tenant is created on — e.g. the `.ref.uuid` output of the meshstack_platform resource/backplane that owns it."
}

variable "landing_zone_name" {
  type        = string
  nullable    = false
  description = "Name of the landing zone on that platform the tenant is placed in — e.g. the `.ref.name` output of the meshLandingZone that owns it."
}

variable "workspace_expiry_tag_key" {
  type        = string
  nullable    = false
  default     = "expiry"
  description = "Tag key the workspace's expiry date is written under, on every workspace this definition creates."
}

variable "workspace_role_name" {
  type        = string
  nullable    = false
  default     = "Workspace Owner"
  description = "meshStack workspace role granted to the workspace owner on every workspace this definition creates."
}

variable "project_role_name" {
  type        = string
  nullable    = false
  default     = "Project Admin"
  description = "meshStack project role granted to the project admin on every project this definition creates."
}

variable "bbd_display_name" {
  type        = string
  nullable    = false
  default     = "meshStack Workspace Starterkit"
  description = "Display name of the building block definition. One instance can deploy several flavours of this starterkit side by side — e.g. a long-lived team workspace and a time-boxed university workspace — and without distinct names the panel shows them as duplicates."
}

variable "bbd_description" {
  type        = string
  nullable    = false
  default     = "Creates a new meshStack workspace with a self-tracked TTL, a payment method, a project with a tenant of a given platform/landing zone, and the initial workspace and project role bindings."
  description = "Description of the building block definition, shown next to its display name in the panel."
}

variable "workspace_ttl_days_default" {
  type        = number
  default     = 30
  description = "Default of the `Workspace TTL (Days)` user input. A flavour handing out long-lived team workspaces needs a far larger default than a time-boxed one. Set it to `null` to make the input optional instead: whoever orders may then leave it blank, and a workspace ordered without a TTL never expires."
}

variable "payment_method_amount_default" {
  type        = number
  nullable    = false
  default     = 100
  description = "Default of the `Payment Method Amount` user input. Set it per flavour, e.g. a small budget for a university workspace and a generous one for a team workspace."
}

variable "workspace_identifier_pattern" {
  type        = string
  nullable    = false
  default     = "^[a-zA-Z0-9-]{1,63}$"
  description = "Regex the workspace identifier must match. The default is the widest form meshStack accepts, but instances cap workspace identifiers at 16 characters, so a deployment usually narrows it to its own rule."
}

variable "workspace_identifier_error_message" {
  type        = string
  nullable    = false
  default     = "Letters, digits and dashes only, at most 63 characters."
  description = "Message shown when the workspace identifier does not match `workspace_identifier_pattern`. Change it together with the pattern — it is the only place the rule is spelled out for the orderer."
}

variable "project_identifier_pattern" {
  type        = string
  nullable    = false
  default     = "^[a-zA-Z0-9-]{1,63}$"
  description = "Regex the project identifier must match."
}

variable "project_identifier_error_message" {
  type        = string
  nullable    = false
  default     = "Letters, digits and dashes only, at most 63 characters."
  description = "Message shown when the project identifier does not match `project_identifier_pattern`."
}

variable "bbd_readme" {
  type        = string
  default     = null
  description = "Replaces the readme the building block definition shows whoever orders it. Unset keeps the module's own, which documents the TTL and the shared responsibilities as this module implements them — so override it to change tone or language, or to add instance-specific guidance, not to describe different behaviour."
}

variable "api_key_lifetime_days" {
  type        = number
  nullable    = false
  default     = 90
  description = "How long the backplane's API key stays valid, in days. meshStack requires an expiry and caps how far out it may sit, so it cannot be turned off. The expiry rolls forward on the first apply past half this many days — see backplane/README.md, an expired key also stops the runs that clean up expired workspaces."
}

variable "additional_api_key_permissions" {
  type        = list(string)
  nullable    = false
  default     = []
  description = "Permissions to add to the ones the backplane grants its API key. See backplane/README.md."
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    tags = object({
      building_block = map(list(string))
      workspace      = map(list(string))
      payment_method = map(list(string))
      project        = map(list(string))
    })
  })
  description = "Shared meshStack context. `tags.building_block` is forwarded to the building block definition's own metadata; `tags.workspace`, `tags.payment_method` and `tags.project` are passed through as a static input, merged onto the workspace (alongside the mandatory expiry tag, see workspace_expiry_tag_key), the payment method and the project this building block creates."
}

variable "hub" {
  type = object({
    git_ref   = optional(string, "main")
    bbd_draft = optional(bool, true)
  })
  const = true
  default = {
    git_ref   = "main"
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
  # A default and an optional input are mutually exclusive: a prefilled value can be changed but
  # never cleared, so only a deployment that sets no default lets an orderer opt out of expiry.
  workspace_ttl_optional = var.workspace_ttl_days_default == null

  platform_ref     = { uuid = var.platform_uuid, kind = "meshPlatform" }
  landing_zone_ref = { name = var.landing_zone_name, kind = "meshLandingZone" }

  default_readme = chomp(<<-EOT
    Creates a fully onboarded meshStack workspace in one order: a workspace tagged with an expiry
    date, a payment method, a project with a tenant on any already-registered platform, and the
    initial workspace and project role bindings.

    ## 🎯 When to use it

    Order this building block when you:
    - Need to onboard a new customer or team into meshStack without creating the workspace, payment
      method, project and tenant by hand.
    - Want every new workspace to start with an expiry tag so it can be tracked and cleaned up.
    - Want an owner assigned to the new workspace and project from the start, not added as a
      follow-up step.

    ## 💡 Usage examples

    **Example 1: Onboard a new customer workspace**
    A platform admin orders this building block to spin up a workspace for a new customer, complete
    with a payment method, a project+tenant and the customer's contact set as owner of both.

    **Example 2: Time-boxed sandbox**
    A platform admin creates a sandbox workspace for an evaluation, setting a TTL that matches the
    evaluation's length so it is cleaned up on its own once that many days have passed.

    ## 🗑️ Self-destructs after its TTL

    The building block tracks its own creation date and computes the expiry date itself — you tell it
    how many days the workspace should live (**Workspace TTL (Days)**), not a specific date. Only a
    platform admin can change that value after ordering, not the application team. That same computed
    date is written to the workspace's expiry tag and to the payment method's own expiration date, so
    nothing outlives the workspace it belongs to. Every resource it creates is destroyed automatically
    the next time it runs after that many days have passed — the workspace, the payment method, the
    project and the tenant, all in one run. The block itself is not deleted, only what it created.

    If this deployment lets you leave **Workspace TTL (Days)** blank, an order without a TTL creates
    a workspace that never expires: nothing carries an expiry date and no run destroys anything.

    ## 📊 Shared Responsibility

    | Responsibility | Platform Team | Application Team |
    |---|:---:|:---:|
    | Order this building block and choose the workspace, payment method and project details | ✅ | ❌ |
    | Provide the platform and landing zone the tenant is created on | ✅ | ❌ |
    | Deploy the backplane that mints the API key this building block authenticates with | ✅ | ❌ |
    | Assign the initial owner of the workspace and project | ✅ | ❌ |
    | Choose the TTL when ordering, and extend it later if needed | ✅ | ❌ |
    | Use the workspace, project and tenant once created | ❌ | ✅ |
    | Order further building blocks inside the project | ❌ | ✅ |
    EOT
  )
}

module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/meshstack/workspace-starterkit/backplane?ref=${var.hub.git_ref}"

  meshstack_workspace_identifier = var.meshstack.owning_workspace_identifier
  api_key_display_name           = var.bbd_display_name
  api_key_lifetime_days          = var.api_key_lifetime_days
  additional_api_key_permissions = var.additional_api_key_permissions
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags.building_block
  }

  spec = {
    display_name     = var.bbd_display_name
    symbol           = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/meshstack/workspace-starterkit/buildingblock/logo.png"
    description      = var.bbd_description
    target_type      = "WORKSPACE_LEVEL"
    run_transparency = true

    readme = coalesce(var.bbd_readme, local.default_readme)
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"

    implementation = {
      terraform = {
        terraform_version              = "1.12.5"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/meshstack/workspace-starterkit/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    # No `permissions`: the run authenticates as the backplane's key through the environment inputs
    # below, not with its own token. `MESHSTACK_ENDPOINT` is already in every run's environment.

    inputs = {
      MESHSTACK_API_KEY = {
        display_name    = "MESHSTACK_API_KEY"
        description     = "Client id of the backplane's admin-scoped API key, which the meshStack provider inside the run reads from its environment."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(module.backplane.api_key_client_id)
      }

      MESHSTACK_API_SECRET = {
        display_name    = "MESHSTACK_API_SECRET"
        description     = "Client secret paired with MESHSTACK_API_KEY."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        sensitive = {
          argument = {
            secret_value   = module.backplane.api_key_client_secret
            secret_version = nonsensitive(sha256(module.backplane.api_key_client_secret))
          }
        }
      }

      # ── Set by the platform team ──

      platform_ref = {
        display_name    = "Platform Reference"
        description     = "HCL object referencing the meshPlatform the tenant is created on."
        type            = "CODE"
        assignment_type = "STATIC"
        # jsonencode twice is correct for structured inputs, see
        # https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block_definition#argument-1
        argument = jsonencode(jsonencode(local.platform_ref))
      }

      landing_zone_ref = {
        display_name    = "Landing Zone Reference"
        description     = "HCL object referencing the landing zone the tenant is placed in."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(local.landing_zone_ref))
      }

      workspace_expiry_tag_key = {
        display_name    = "Workspace Expiry Tag Key"
        description     = "Tag key the workspace's expiry date is written under."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.workspace_expiry_tag_key)
      }

      workspace_role_name = {
        display_name    = "Workspace Role"
        description     = "meshStack workspace role granted to the workspace owner."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.workspace_role_name)
      }

      project_role_name = {
        display_name    = "Project Role"
        description     = "meshStack project role granted to the project admin."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.project_role_name)
      }

      tags = {
        display_name    = "Tags"
        description     = "HCL object of additional tags applied to the workspace, payment method and project."
        type            = "CODE"
        assignment_type = "STATIC"
        argument = jsonencode(jsonencode({
          workspace      = var.meshstack.tags.workspace
          payment_method = var.meshstack.tags.payment_method
          project        = var.meshstack.tags.project
        }))
      }

      # ── Chosen by whoever orders this building block ──

      workspace_identifier = {
        display_name                   = "Workspace Identifier"
        description                    = "Identifier for the new workspace."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = var.workspace_identifier_pattern
        validation_regex_error_message = var.workspace_identifier_error_message
        display_order                  = 1
      }

      workspace_display_name = {
        display_name    = "Workspace Display Name"
        description     = "Display name for the new workspace."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        display_order   = 2
      }

      workspace_ttl_days = {
        display_name    = "Workspace TTL (Days)"
        description     = "Number of days after creation before the workspace, payment method, project and tenant are destroyed.${local.workspace_ttl_optional ? " Leave it blank for a workspace that never expires." : ""}"
        type            = "INTEGER"
        assignment_type = "USER_INPUT"
        default_value   = local.workspace_ttl_optional ? null : jsonencode(var.workspace_ttl_days_default)
        is_optional     = local.workspace_ttl_optional
        display_order   = 3
      }

      workspace_owner_username = {
        display_name    = "Owner"
        description     = "Username granted the workspace role above on the new workspace and the project role above on the new project — one owner for both."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        display_order   = 4
      }

      payment_method_amount = {
        display_name    = "Payment Method Amount"
        description     = "Budget amount for the payment method."
        type            = "INTEGER"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(var.payment_method_amount_default)
        display_order   = 5
      }

      project_identifier = {
        display_name                   = "Project Identifier"
        description                    = "Identifier for the project created inside the new workspace."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = var.project_identifier_pattern
        validation_regex_error_message = var.project_identifier_error_message
        display_order                  = 6
      }

      project_display_name = {
        display_name    = "Project Display Name"
        description     = "Display name for the project."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        display_order   = 7
      }

    }

    outputs = {
      workspace_identifier = {
        display_name    = "Workspace Identifier"
        type            = "STRING"
        assignment_type = "NONE"
      }

      payment_method_identifier = {
        display_name    = "Payment Method Identifier"
        type            = "STRING"
        assignment_type = "NONE"
      }

      project_identifier = {
        display_name    = "Project Identifier"
        type            = "STRING"
        assignment_type = "NONE"
      }

      workspace_expiry_date = {
        display_name    = "Workspace Expiry Date"
        type            = "STRING"
        assignment_type = "NONE"
      }
    }
  }
}

terraform {
  required_version = ">= 1.12.0"

  required_providers {
    meshstack = {
      source = "meshcloud/meshstack"
      # 0.25.2 adds `version_spec.inputs.*.is_optional`, which makes the TTL input skippable.
      version = ">= 0.25.2"
    }
  }
}
