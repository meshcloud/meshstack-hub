variable "litellm_api_base" {
  type        = string
  description = "Base URL of the LiteLLM gateway, for example 'https://litellm.example.com'. Every team and virtual key this definition creates lives on this gateway."
}

variable "litellm_admin_api_key" {
  type        = string
  sensitive   = true
  description = "LiteLLM admin key the building block authenticates with. It needs permission to create teams and keys."
}

variable "litellm_platform_type_name" {
  type        = string
  default     = "LiteLLM"
  description = "Name of the meshStack platform type the LiteLLM platform is registered under. It must match the platform type used by the `ai/litellm` module."
}

variable "litellm_team_models" {
  type        = list(string)
  default     = []
  description = "Names of the models on the gateway that every team created by this definition may call. An empty list sends no allow-list to LiteLLM. Create one definition per landing zone to grant different model sets."
}

variable "litellm_team_max_budget" {
  type        = number
  default     = 100
  description = "Spending limit of a team for one budget period, in the currency the gateway reports spend in. LiteLLM blocks the team once the limit is reached."
}

variable "litellm_team_budget_duration" {
  type        = string
  default     = "30d"
  description = "Length of one budget period, after which LiteLLM resets the spend counter. Written as a LiteLLM duration such as '30d', '7d' or '1h'."
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
  `git_ref`: Hub release reference. Set to a tag (e.g. 'v1.2.3') or branch or commit sha of meshcloud/meshstack-hub repo.
  `bbd_draft`: If true, allows changing the building block definition for upgrading dependent building blocks.
  EOT
}

output "building_block_definition" {
  description = "BBD is consumed in building block compositions. Add it to `spec.mandatory_building_block_refs` of an AI landing zone so meshStack provisions the team when a tenant is created."
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name        = "LiteLLM Team"
    symbol              = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/ai/litellm-team/buildingblock/logo.png"
    description         = "Creates the LiteLLM team of a tenant with a budget, and a virtual key scoped to that team."
    support_url         = "https://docs.litellm.ai/docs/proxy/virtual_keys"
    target_type         = "TENANT_LEVEL"
    run_transparency    = true
    supported_platforms = [{ name = var.litellm_platform_type_name }]

    # The application team never orders this block by hand. An AI landing zone lists it in
    # `spec.mandatory_building_block_refs`, so meshStack provisions the team and the key when the
    # tenant is created.
    use_in_landing_zones_only = true

    readme = chomp(<<-EOT
      This building block gives your project its own team on the LiteLLM gateway, with a budget and
      a virtual key that is scoped to that team. meshStack creates both when your tenant in the AI
      landing zone is created, so there is nothing to order and nothing to fill in.

      ## 🎯 When to use it

      Use this building block when you:
      - Want a governed OpenAI-compatible endpoint for your application instead of a credential shared across the whole platform.
      - Need spend for your project to be counted and capped on its own.
      - Want the platform team to decide which models you may call, through the landing zone you picked.

      ## 💡 Usage examples

      **Example 1: A chat assistant in a web application**
      A team creates a tenant in the AI landing zone and reads the base URL and the virtual key from
      the outputs. The team stores both in a Kubernetes secret and points the OpenAI client library
      of the application at them.

      **Example 2: Keeping an evaluation job inside a budget**
      A team runs a nightly job that grades model answers. The job uses the same virtual key, so its
      spend counts against the project budget and LiteLLM stops the calls before the budget is
      exceeded rather than after the invoice arrives.

      ## 🔑 Calling the gateway

      The `api_base` output already ends in `/v1`. Send the virtual key as a bearer token:

      ```sh
      curl "$API_BASE/models" \
        -H "Authorization: Bearer $VIRTUAL_KEY"
      ```

      LiteLLM returns the virtual key once, when the building block runs, and never shows it again.
      Copy it into your own secret store.

      ## 📊 Shared Responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Operate the LiteLLM gateway and the model backends behind it | ✅ | ❌ |
      | Set the budget, the budget period and the allowed models per landing zone | ✅ | ❌ |
      | Create the team and the virtual key when the tenant is created | ✅ | ❌ |
      | Store the virtual key in the application's own secret store | ❌ | ✅ |
      | Stay within the granted budget and the allowed models | ❌ | ✅ |
      | Build and operate the application that calls the gateway | ❌ | ✅ |
      EOT
    )
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"

    # One tenant is one LiteLLM team. Applying the block a second time in the same tenant would
    # create a second team and a second key, so meshStack refuses it.
    only_apply_once_per_tenant = true

    implementation = {
      terraform = {
        terraform_version              = "1.12.2"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/ai/litellm-team/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      litellm_api_base = {
        display_name    = "LiteLLM API Base URL"
        description     = "Base URL of the LiteLLM gateway the team is created on."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.litellm_api_base)
      }

      litellm_api_key = {
        display_name    = "LiteLLM Admin Key"
        description     = "Admin key the building block authenticates with against the LiteLLM API."
        type            = "STRING"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value   = var.litellm_admin_api_key
            secret_version = nonsensitive(sha256(var.litellm_admin_api_key))
          }
        }
      }

      workspace_identifier = {
        display_name    = "Workspace Identifier"
        description     = "Identifier of the meshStack workspace, used in the team alias and in the team metadata."
        type            = "STRING"
        assignment_type = "WORKSPACE_IDENTIFIER"
      }

      project_identifier = {
        display_name    = "Project Identifier"
        description     = "Identifier of the meshStack project, used in the team alias and in the team metadata."
        type            = "STRING"
        assignment_type = "PROJECT_IDENTIFIER"
      }

      meshstack_tenant_uuid = {
        display_name    = "Tenant UUID"
        description     = "UUID of the meshStack tenant, written to the team metadata so an operator can trace a team back to its tenant."
        type            = "STRING"
        assignment_type = "MESHSTACK_TENANT_UUID"
      }

      models = {
        display_name    = "Allowed Models"
        description     = "Names of the models on the gateway that the team may call."
        type            = "CODE"
        assignment_type = "STATIC"
        # jsonencode twice is correct, see https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block_definition#argument-1
        argument = jsonencode(jsonencode(var.litellm_team_models))
      }

      max_budget = {
        display_name    = "Budget"
        description     = "Spending limit of the team for one budget period."
        type            = "INTEGER"
        assignment_type = "STATIC"
        argument        = jsonencode(var.litellm_team_max_budget)
      }

      budget_duration = {
        display_name    = "Budget Duration"
        description     = "Length of one budget period, for example '30d'."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.litellm_team_budget_duration)
      }
    }

    outputs = {
      team_id = {
        display_name    = "Team ID"
        description     = "ID of the LiteLLM team. It becomes the platform tenant ID, so building blocks ordered later can bind their resources to this team."
        type            = "STRING"
        assignment_type = "PLATFORM_TENANT_ID"
      }

      team_alias = {
        display_name    = "Team Alias"
        description     = "Alias of the LiteLLM team, shown in the LiteLLM UI."
        type            = "STRING"
        assignment_type = "NONE"
      }

      virtual_key = {
        display_name    = "Virtual Key"
        description     = "The key the application sends as a bearer token. LiteLLM returns it only at creation."
        type            = "STRING"
        assignment_type = "NONE"
      }

      key_id = {
        display_name    = "Key ID"
        description     = "Hash LiteLLM identifies the virtual key by."
        type            = "STRING"
        assignment_type = "NONE"
      }

      api_base = {
        display_name    = "API Base URL"
        description     = "OpenAI-compatible base URL of the gateway, including the '/v1' suffix."
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
      version = ">= 0.23.0"
    }
  }
}
