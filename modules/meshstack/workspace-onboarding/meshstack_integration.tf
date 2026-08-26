variable "stackit_platform_identifier" {
  type        = string
  nullable    = false
  description = "Identifier (`<platform-name>.<location-name>`) of the STACKIT platform the tenant is created on. Must already be registered and published to `meshstack.owning_workspace_identifier`."
}

variable "stackit_landing_zone_name" {
  type        = string
  nullable    = false
  description = "Name of the landing zone on the STACKIT platform the tenant is placed in."
}

variable "meshstack_admin_api_key" {
  type        = string
  sensitive   = true
  nullable    = false
  description = "Admin-scoped meshStack API key, injected once by the platform team when deploying this definition, paired with meshstack_admin_api_secret. Creating a workspace and a payment method needs `ADM_*` permissions meshStack never grants to a building block's own ephemeral run token, so the building block authenticates every resource it manages through this key/secret pair instead."
}

variable "meshstack_admin_api_secret" {
  type        = string
  sensitive   = true
  nullable    = false
  description = "Admin-scoped meshStack API secret, paired with meshstack_admin_api_key."
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

variable "tags" {
  type = object({
    workspace      = optional(map(list(string)), {})
    payment_method = optional(map(list(string)), {})
    project        = optional(map(list(string)), {})
  })
  nullable = false
  default = {
    workspace      = {}
    payment_method = {}
    project        = {}
  }
  description = "Additional tags merged onto the created workspace (alongside the mandatory expiry tag, see workspace_expiry_tag_key), payment method and project."
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    tags                        = optional(map(list(string)), {})
  })
  description = "Shared meshStack context. Tags are optional and propagated to building block definition metadata."
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
  identifier_regex = "^[a-zA-Z0-9-]{1,63}$"
  date_regex       = "^\\d{4}-\\d{2}-\\d{2}$"
}

# Resolved once here, in the context of the deploying (`meshstack.owning_workspace_identifier`)
# workspace, and passed to the building block as STATIC inputs — the same pattern
# `stackit-project-starterkit` uses for `platform_ref` / `landing_zone_refs`. This avoids the building
# block having to look up the platform from inside the brand-new workspace it just created, which may
# not have the STACKIT platform published to it yet.
data "meshstack_platforms" "available" {
  owned_by_workspace = var.meshstack.owning_workspace_identifier
}

data "meshstack_landingzones" "available" {
  platform_uuid = local.platform.metadata.uuid
}

locals {
  platform = one([
    for p in data.meshstack_platforms.available.platforms : p if p.identifier == var.stackit_platform_identifier
  ])
  landing_zone = one([
    for lz in data.meshstack_landingzones.available.landing_zones : lz if lz.metadata.name == var.stackit_landing_zone_name
  ])
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name = "meshStack Workspace Onboarding"
    symbol       = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/meshstack/workspace-onboarding/buildingblock/logo.png"
    description  = "Creates a new meshStack workspace with a configurable expiry tag, a payment method, a project with a STACKIT tenant, and the initial workspace and project role bindings."
    # No `supported_platforms`: meshStack rejects a workspace-scoped definition that declares any,
    # with `400 A Workspace scoped Building Block Definition can not have supported platforms`.
    target_type      = "WORKSPACE_LEVEL"
    run_transparency = true

    readme = chomp(<<-EOT
    Creates a fully onboarded meshStack workspace in one order: a workspace tagged with an expiry
    date, a payment method, a project with a STACKIT tenant, and the initial workspace and project
    role bindings.

    ## 🎯 When to use it

    Order this building block when you:
    - Need to onboard a new customer or team into meshStack without creating the workspace, payment
      method, project and STACKIT tenant by hand.
    - Want every new workspace to start with an expiry tag so it can be tracked and cleaned up.
    - Want the workspace owner and project admin assigned from the start, not added as a follow-up
      step.

    ## 💡 Usage examples

    **Example 1: Onboard a new customer workspace**
    A platform admin orders this building block to spin up a workspace for a new customer, complete
    with a payment method, a STACKIT project and the customer's contact set as workspace owner and
    project admin.

    **Example 2: Time-boxed sandbox**
    A platform admin creates a sandbox workspace for an evaluation, setting the expiry date to the
    evaluation's end date so it shows up for cleanup once that date passes.

    ## 🗑️ Self-destructs after expiry

    Every resource this building block creates is destroyed automatically the next time it runs after
    the workspace's expiry date has passed — the workspace, the payment method, the project and the
    STACKIT tenant, all in one run. Update the **Workspace Expiry Date** input to push the date out if
    the workspace should keep living; the block itself is not deleted, only what it created.

    ## 📊 Shared Responsibility

    | Responsibility | Platform Team | Application Team |
    |---|:---:|:---:|
    | Order this building block and choose the workspace, payment method and project details | ✅ | ❌ |
    | Provide the STACKIT platform and landing zone the tenant is created on | ✅ | ❌ |
    | Provide the admin-scoped API key/secret this building block authenticates with | ✅ | ❌ |
    | Assign the initial workspace owner and project admin | ✅ | ❌ |
    | Extend the expiry date before it passes, if the workspace should keep living | ✅ | ❌ |
    | Use the workspace, project and STACKIT tenant once created | ❌ | ✅ |
    | Order further building blocks inside the project | ❌ | ✅ |
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
        repository_path                = "modules/meshstack/workspace-onboarding/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    # No `permissions`: every resource is managed through the admin-scoped provider alias
    # authenticated with `meshstack_admin_api_key` / `meshstack_admin_api_secret`, not this run's
    # ephemeral token.

    inputs = {
      meshstack_admin_api_key = {
        display_name    = "meshStack Admin API Key"
        description     = "Admin-scoped meshStack API key used to create the workspace and payment method, which need permissions this block's own ephemeral run token cannot hold. Paired with meshStack Admin API Secret."
        type            = "STRING"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value   = var.meshstack_admin_api_key
            secret_version = nonsensitive(sha256(var.meshstack_admin_api_key))
          }
        }
      }

      meshstack_admin_api_secret = {
        display_name    = "meshStack Admin API Secret"
        description     = "Admin-scoped meshStack API secret, paired with meshStack Admin API Key."
        type            = "STRING"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value   = var.meshstack_admin_api_secret
            secret_version = nonsensitive(sha256(var.meshstack_admin_api_secret))
          }
        }
      }

      # ── Set by the platform team ──

      platform_ref = {
        display_name    = "Platform Reference"
        description     = "HCL object referencing the STACKIT meshPlatform the tenant is created on."
        type            = "CODE"
        assignment_type = "STATIC"
        # jsonencode twice is correct for structured inputs, see
        # https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block_definition#argument-1
        argument = jsonencode(jsonencode(local.platform.ref))
      }

      landing_zone_ref = {
        display_name    = "Landing Zone Reference"
        description     = "HCL object referencing the landing zone the tenant is placed in."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(local.landing_zone.ref))
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
        argument        = jsonencode(jsonencode(var.tags))
      }

      # ── Chosen by whoever orders this building block ──

      workspace_identifier = {
        display_name                   = "Workspace Identifier"
        description                    = "Identifier for the new workspace."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = local.identifier_regex
        validation_regex_error_message = "Letters, digits and dashes only, at most 63 characters."
      }

      workspace_display_name = {
        display_name    = "Workspace Display Name"
        description     = "Display name for the new workspace."
        type            = "STRING"
        assignment_type = "USER_INPUT"
      }

      workspace_expiry_date = {
        display_name                   = "Workspace Expiry Date"
        description                    = "Written to the workspace's expiry tag (see Workspace Expiry Tag Key), as YYYY-MM-DD. The next run of this building block after this date destroys the workspace and everything it created — update this value to push the date out first if that is not wanted."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        updateable_by_consumer         = true
        value_validation_regex         = local.date_regex
        validation_regex_error_message = "Must be a date in YYYY-MM-DD format."
      }

      workspace_owner_username = {
        display_name    = "Workspace Owner"
        description     = "Username granted the workspace role above on the new workspace."
        type            = "STRING"
        assignment_type = "USER_INPUT"
      }

      payment_method_amount = {
        display_name    = "Payment Method Amount"
        description     = "Budget amount for the payment method."
        type            = "INTEGER"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(0)
      }

      payment_method_expiration_date = {
        display_name                   = "Payment Method Expiration Date"
        description                    = "Optional expiration date of the payment method itself, as YYYY-MM-DD. Independent of the workspace's `expiry` tag; leave empty for no expiration."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        updateable_by_consumer         = true
        default_value                  = jsonencode("")
        value_validation_regex         = "^$|${local.date_regex}"
        validation_regex_error_message = "Must be empty or a date in YYYY-MM-DD format."
      }

      project_identifier = {
        display_name                   = "Project Identifier"
        description                    = "Identifier for the project created inside the new workspace."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = local.identifier_regex
        validation_regex_error_message = "Letters, digits and dashes only, at most 63 characters."
      }

      project_display_name = {
        display_name    = "Project Display Name"
        description     = "Display name for the project."
        type            = "STRING"
        assignment_type = "USER_INPUT"
      }

      project_admin_username = {
        display_name    = "Project Admin"
        description     = "Username granted the project role above on the new project."
        type            = "STRING"
        assignment_type = "USER_INPUT"
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

      stackit_project_url = {
        display_name    = "Open STACKIT Project"
        type            = "STRING"
        assignment_type = "RESOURCE_URL"
      }

      summary = {
        display_name    = "Summary"
        type            = "STRING"
        assignment_type = "SUMMARY"
      }
    }
  }
}

terraform {
  required_version = ">= 1.12.0"

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.24.0"
    }
  }
}
