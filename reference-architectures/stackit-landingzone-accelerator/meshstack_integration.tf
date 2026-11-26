variable "accelerator_ref" {
  type        = string
  default     = "v2.3.0"
  nullable    = false
  description = "Accelerator git ref the order form suggests. Each order can set its own."
}

variable "bbd_display_name" {
  type        = string
  default     = null
  description = "Overrides the name of the marketplace entry application teams see in the catalog."
}

variable "bbd_description" {
  type        = string
  default     = null
  description = "Overrides the one-line description shown next to the marketplace entry."
}

variable "bbd_readme" {
  type        = string
  default     = null
  description = "Overrides the markdown readme shown in the marketplace before ordering."
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    tags                        = optional(map(list(string)), {})
    runner_ref = optional(object({
      kind = string
      uuid = string
    }))
  })
  description = "Shared meshStack context, see docs."
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
  `bbd_draft`: If true, the STACKIT Project definition is kept in draft mode. This definition is always a draft, so it stays in the owning workspace.
  EOT
}

variable "approval_policies" {
  type = object({
    building_block_creation = optional(bool, false)
    user_input_changes      = optional(bool, false)
    any_input_changes       = optional(bool, false)
    manual_triggers         = optional(bool, false)
    version_upgrade         = optional(bool, false)
  })
  nullable = false
  default = {
    building_block_creation = false
    user_input_changes      = false
    any_input_changes       = false
    manual_triggers         = false
    version_upgrade         = false
  }
  description = "Run triggers that need an operator's approval before a run of this architecture is applied. The defaults are the provider's own, and the provider asserts them whenever the definition sets no policies — so a gate switched on in meshPanel is turned off again by the next apply unless it is set here."
}

output "building_block_definition" {
  description = "BBD is consumed in building block compositions."
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = meshstack_building_block_definition.this.version_latest
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name          = coalesce(var.bbd_display_name, "STACKIT Landing Zone Accelerator Reference Architecture")
    display_name_template = "STACKIT Landing Zone Accelerator {{platform_identifier}}"
    symbol                = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/reference-architectures/stackit-landingzone-accelerator/buildingblock/logo.png"
    description           = coalesce(var.bbd_description, "Applies the STACKIT Landing Zone Accelerator with the tfvars file the STACKIT Landing Zone Configurator exports, and registers a STACKIT platform with one landing zone per landing zone of the export.")
    support_url           = "https://github.com/stackitcloud/stackit-landing-zone"
    target_type           = "WORKSPACE_LEVEL"
    run_transparency      = true
    approval_policies     = var.approval_policies

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
    This building block builds a STACKIT foundation with the
    [STACKIT Landing Zone Accelerator](https://github.com/stackitcloud/stackit-landing-zone) and
    turns it into a meshStack platform. You paste the tfvars file the STACKIT Landing Zone
    Configurator exports, and the run applies the accelerator's `src/` with exactly these values.
    It then registers a STACKIT platform with one landing zone per entry of the export's
    `landing_zones`, and the **STACKIT Project** building block. It creates a tenant's project in the
    accelerator's corporate or public folder, as the entry's `corporate` flag says.

    ## 🎯 When to use it

    Use this building block when you:
    - designed a STACKIT landing zone in the STACKIT Landing Zone Configurator and want to deploy it.
    - want application teams to get STACKIT projects in the accelerator's folders from meshStack.

    ## 💡 Usage examples

    **Example 1: Deploy a Configurator design**
    A platform engineer exports the tfvars file from the Configurator, pastes it into **Landing
    Zone tfvars** together with the key of an organization owner service account, and orders the
    building block. The run creates the folders, the management project and everything else the
    export describes.

    **Example 2: Offer projects in the accelerator's folders**
    After the run, application teams add **STACKIT Project** from the marketplace to a tenant on
    one of the new landing zones, for example `<platform identifier>-corp-exmpl` for the export's
    entry `corp-exmpl`. The project is created in that landing zone's folder.

    ## 🔑 Authentication

    The run authenticates as the service account whose key you paste into **STACKIT Service
    Account Key**. The accelerator creates folders and assigns organization roles, so the service
    account must be an owner of the organization.

    ## ⚠️ Deletion

    Deleting this building block destroys everything the accelerator created, including its landing
    zone projects. Delete the tenant projects first.

    ## 📊 Shared responsibility

    | Responsibility | Platform Team | Application Team |
    |---|:---:|:---:|
    | Design the landing zone in the Configurator and paste the export | ✅ | ❌ |
    | Provide the organization owner service account key | ✅ | ❌ |
    | Deploy the accelerator foundation and the STACKIT platform | ✅ | ❌ |
    | Add STACKIT Project from the marketplace to their tenants | ❌ | ✅ |
    | Manage workloads inside the provisioned STACKIT projects | ❌ | ✅ |
    EOT
    ))
  }

  version_spec = {
    draft         = true
    runner_ref    = var.meshstack.runner_ref
    deletion_mode = "DELETE"

    permissions = [
      "INTEGRATION_LIST",
      "BUILDINGBLOCKDEFINITION_LIST",
      "BUILDINGBLOCKDEFINITION_SAVE",
      "BUILDINGBLOCKDEFINITION_DELETE",
      "BUILDINGBLOCKRUNNER_LIST",
      "LANDINGZONE_LIST",
      "LANDINGZONE_SAVE",
      "LANDINGZONE_DELETE",
      "PLATFORMINSTANCE_LIST",
      "PLATFORMINSTANCE_SAVE",
      "PLATFORMINSTANCE_DELETE"
    ]

    implementation = {
      terraform = {
        terraform_version              = "1.12.5"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "reference-architectures/stackit-landingzone-accelerator/buildingblock"
        ref_name                       = var.hub.git_ref
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      platform_identifier = {
        display_name                   = "Platform Identifier"
        description                    = "Identifier of the STACKIT platform created in meshStack, and prefix of its landing zones (letters, digits and dashes only)."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[a-zA-Z0-9-]+$"
        validation_regex_error_message = "platform_identifier must only contain letters, digits, and dashes."
        display_order                  = 10
      }

      playground_mode = {
        display_name    = "Playground Mode"
        description     = "Throwaway deployment: the identifier gets a random suffix and the definition is named after it, so the block can be ordered more than once in one meshStack. Publish such a platform only to test. Cannot change after the order."
        type            = "BOOLEAN"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(false)
        display_order   = 15
      }

      landing_zone_tfvars = {
        display_name           = "Landing Zone tfvars"
        description            = "The tfvars file the STACKIT Landing Zone Configurator exports, pasted unchanged."
        type                   = "CODE"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        display_order          = 20
      }

      accelerator_ref = {
        display_name           = "Accelerator Version"
        description            = "Git ref of the STACKIT Landing Zone Accelerator to apply, such as a tag. The export's `Accelerator source` line names the commit it was made for; another ref works when the export's variables fit that version."
        type                   = "STRING"
        assignment_type        = "USER_INPUT"
        default_value          = jsonencode(var.accelerator_ref)
        updateable_by_consumer = true
        display_order          = 30
      }

      STACKIT_SERVICE_ACCOUNT_KEY = {
        display_name           = "STACKIT Service Account Key"
        description            = "Full key JSON of a service account that owns the STACKIT organization of the export. Every STACKIT provider of the run reads it from the environment."
        type                   = "CODE"
        assignment_type        = "USER_INPUT"
        is_environment         = true
        updateable_by_consumer = true
        sensitive              = {}
        display_order          = 40
      }

      runner_ref = {
        display_name    = "Runner"
        description     = "Runner of the STACKIT Project definition. Set to `{}` to use the default shared runner."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(coalesce(var.meshstack.runner_ref, {})))
        display_order   = 120
      }

      workspace = {
        display_name    = "Workspace Identifier"
        description     = "Workspace that will own the created platform, landing zones and STACKIT Project definition."
        type            = "STRING"
        assignment_type = "WORKSPACE_IDENTIFIER"
        display_order   = 900
      }

      hub = {
        display_name    = "Hub"
        description     = "HCL object with `git_ref` (meshstack-hub reference used to source the nested STACKIT integration) and `bbd_draft` (draft state of the STACKIT Project definition)."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.hub))
        display_order   = 1000
      }
    }

    outputs = {
      management_project_id = {
        display_name    = "Management Project ID"
        type            = "STRING"
        assignment_type = "NONE"
      }

      management_project_url = {
        display_name    = "Open Management Project"
        type            = "STRING"
        assignment_type = "RESOURCE_URL"
      }

      platform_contract = {
        display_name    = "Platform Contract"
        type            = "STRING"
        assignment_type = "NONE"
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
      version = ">= 0.27.0"
    }
  }
}
