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

variable "stackit_organization_onboarding_enabled" {
  type        = bool
  default     = true
  description = "Whether the project building block adds meshStack project users to the STACKIT organization. Disable if organization membership is managed externally."
}

output "building_block_definition" {
  description = "BBD is consumed in building block compositions."
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
    display_name     = "STACKIT Sandbox Landing Zone"
    symbol           = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/reference-architectures/stackit-sandbox-landingzone/buildingblock/logo.png"
    description      = "Onboards a STACKIT sandbox platform into meshStack: creates a location, a STACKIT resourcemanager folder and the STACKIT Project platform with its default landing zone."
    support_url      = "https://portal.stackit.cloud"
    target_type      = "WORKSPACE_LEVEL"
    run_transparency = true

    readme = chomp(<<-EOT
    The **STACKIT Sandbox Landing Zone** building block bootstraps a complete STACKIT sandbox platform integration inside a
    meshStack workspace. Running it once turns a STACKIT organization into a sandbox-ready self-service platform: it
    registers a meshStack location, carves out a dedicated STACKIT resourcemanager folder for the workspace and
    wires up the **STACKIT Project** platform together with its default landing zone.

    ## 🎯 When to use it

    Use this building block when you:
    - want to onboard STACKIT in meshStack without manually creating locations, folders and project platform wiring.
    - need a reusable setup for sandbox environments where application teams can request STACKIT projects self-service.

    ## 💡 Usage examples

    **Example 1: Enable a new STACKIT sandbox platform**
    A platform engineer runs this building block once for a workspace to bootstrap the STACKIT location, landing-zone folder
    and default `STACKIT Project` platform so teams can start requesting projects immediately.

    **Example 2: Prepare an isolated training environment**
    For workshops or onboarding waves, the platform team creates a dedicated platform identifier and folder boundary so
    participant projects are provisioned in a controlled area with clear ownership.

    ## 📦 Resources created

    - **meshStack location** – named after the chosen platform identifier.
    - **STACKIT resourcemanager folder** – created under the configured organization and owned by the given owner email.
      New tenant projects are created inside this folder.
    - **STACKIT backplane project** – created directly under the organization to host the project-creation service account.
    - **STACKIT Project platform** – the `STACKIT Project` building block definition, platform and default landing zone,
      including the project-creation service account provisioned in the backplane project.

    ## 🔑 Authentication

    You provide the STACKIT organization UUID, owner email, tags, default role mapping and a service account key as inputs.
    The building block authenticates to STACKIT with the service account key, which needs `resource-manager.admin` on the organization.

    ## 📊 Shared responsibility

    | Responsibility | Platform Team | Application Team |
    |---|:---:|:---:|
    | Provide the STACKIT service account key, organization details, tags and role mapping | ✅ | ❌ |
    | Provision the location, folder and STACKIT Project platform | ✅ | ❌ |
    | Request STACKIT projects through the landing zone | ❌ | ✅ |
    | Manage workloads inside the provisioned STACKIT projects | ❌ | ✅ |
    EOT
    )
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"

    # Ephemeral API key permissions for meshStack resources created by this building block and STACKIT integration.
    permissions = [
      "INTEGRATION_LIST",
      "BUILDINGBLOCKDEFINITION_LIST",
      "BUILDINGBLOCKDEFINITION_SAVE",
      "BUILDINGBLOCKDEFINITION_DELETE",
      "LANDINGZONE_LIST",
      "LANDINGZONE_SAVE",
      "LANDINGZONE_DELETE",
      "PLATFORMINSTANCE_LIST",
      "PLATFORMINSTANCE_SAVE",
      "PLATFORMINSTANCE_DELETE"
    ]

    implementation = {
      terraform = {
        terraform_version              = "1.12.0"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "reference-architectures/stackit-sandbox-landingzone/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      # ── STACKIT authentication (service account key supplied by the operator) ──

      "stackit_service_account_key" = {
        display_name           = "STACKIT Service Account Key"
        description            = "STACKIT service account key JSON with `resource-manager.admin` on the organization. Paste the full JSON as a secret input."
        type                   = "CODE"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        sensitive              = {}
      }

      hub = {
        display_name    = "Hub"
        description     = "JSON object with `git_ref` (meshstack-hub reference used to source the nested STACKIT project integration module) and `bbd_draft` (forwarded to the nested integration's own building block definition draft state)."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.hub))
      }

      # ── Platform configuration (set by the platform team) ──

      stackit_org = {
        display_name                   = "STACKIT Organization UUID"
        description                    = "STACKIT organization UUID under which the landing-zone folder, backplane project and tenant projects are created."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
        validation_regex_error_message = "STACKIT Organization UUID must be a valid UUID."
      }

      stackit_owner_email = {
        display_name    = "STACKIT Owner Email"
        description     = "Owner email assigned to the STACKIT resourcemanager folder and backplane project."
        type            = "STRING"
        assignment_type = "USER_INPUT"
      }

      tags = {
        display_name           = "Tags"
        description            = "JSON object with `landingzone` and `building_block` tag maps forwarded to the STACKIT Project integration module."
        type                   = "CODE"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true

        default_value = jsonencode(jsonencode({
          landingzone    = {}
          building_block = {}
        }))
      }

      role_mapping = {
        display_name           = "STACKIT Project Role Mapping"
        description            = "JSON object mapping meshStack roles from project users to STACKIT project roles. Values can be built-in STACKIT roles or custom STACKIT role names."
        type                   = "CODE"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true

        default_value = jsonencode(jsonencode({
          admin  = ["owner"]
          user   = ["editor"]
          reader = ["reader"]
        }))
      }

      stackit_organization_onboarding_enabled = {
        display_name           = "STACKIT Organization Onboarding Enabled"
        description            = "If true, the nested STACKIT Project integration adds meshStack project users to the STACKIT organization before applying project-level role assignments."
        type                   = "BOOLEAN"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true

        default_value = jsonencode(var.stackit_organization_onboarding_enabled)
      }

      # ── meshStack context ──

      workspace = {
        display_name    = "Workspace Identifier"
        description     = "Workspace that will own the created platform, location and landing zone."
        type            = "STRING"
        assignment_type = "WORKSPACE_IDENTIFIER"
      }

      platform_identifier = {
        display_name                   = "Platform Identifier"
        description                    = "Identifier for the STACKIT sandbox platform created in meshStack (letters, digits and dashes only)."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[a-zA-Z0-9-]+$"
        validation_regex_error_message = "platform_identifier must only contain letters, digits, and dashes."
      }

      use_global_location = {
        display_name    = "Use Global Location"
        description     = "If true, use the existing global meshStack location instead of creating a dedicated location for this platform."
        type            = "BOOLEAN"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(false)
      }
    }

    outputs = {
      lz_folder_container_id = {
        display_name    = "LZ Folder Container ID"
        type            = "STRING"
        assignment_type = "NONE"
      }

      backplane_project_id = {
        display_name    = "Backplane Project ID"
        type            = "STRING"
        assignment_type = "NONE"
      }

      backplane_project_url = {
        display_name    = "Open Backplane Project"
        type            = "STRING"
        assignment_type = "RESOURCE_URL"
      }
    }
  }
}

terraform {
  required_version = ">= 1.12.0"

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.22.0"
    }
  }
}
