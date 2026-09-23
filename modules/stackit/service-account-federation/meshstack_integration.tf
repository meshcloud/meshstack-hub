variable "stackit_organization_id" {
  type        = string
  description = "STACKIT organization ID under which target projects live."
}

variable "stackit_project_id" {
  type        = string
  description = "STACKIT project ID where the backplane service account will be created."
}

variable "stackit_service_account_name" {
  type        = string
  default     = null
  description = "Name of the backplane service account. Defaults to 'mesh-sa-federation'."
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
  })
  description = "Shared meshStack context."
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
  description = "BBD is consumed in building block compositions."
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = meshstack_building_block_definition.this.version_latest
    # Other workspaces may only order a released version. Null until the first release.
    version_ref_release = meshstack_building_block_definition.this.version_latest_release
  }
}

data "meshstack_integrations" "integrations" {}

module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/service-account-federation/backplane?ref=${var.hub.git_ref}"

  project_id           = var.stackit_project_id
  organization_id      = var.stackit_organization_id
  service_account_name = coalesce(var.stackit_service_account_name, "mesh-sa-federation")

  workload_identity_federation = {
    issuer = data.meshstack_integrations.integrations.workload_identity_federation.replicator.issuer
    subjects = [
      "${trimsuffix(data.meshstack_integrations.integrations.workload_identity_federation.replicator.subject, ":replicator")}:workspace.${var.meshstack.owning_workspace_identifier}.buildingblockdefinition.${meshstack_building_block_definition.this.metadata.uuid}"
    ]
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name        = coalesce(var.bbd_display_name, "STACKIT Service Account Federation")
    symbol              = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/stackit/service-account-federation/buildingblock/logo.png"
    description         = coalesce(var.bbd_description, "Lets runs of your workspace's building block definitions act as an existing STACKIT service account via workload identity federation.")
    support_url         = "https://portal.stackit.cloud"
    target_type         = "TENANT_LEVEL"
    run_transparency    = true
    supported_platforms = [{ name = "STACKIT" }]
    readme = coalesce(var.bbd_readme, chomp(<<-EOT
      This building block lets runs of your workspace's own building block definitions act as an
      existing **STACKIT service account** through Workload Identity Federation, so those runs get a
      machine identity against STACKIT without anyone managing a long-lived key.

      ## 🎯 When to use it

      Use this building block when you:
      - Created a service account with the **STACKIT Service Account** building block and want building blocks to deploy as it.
      - Register building block definitions after the service account exists, and so only know their uuids later.

      ## 💡 Usage examples

      **Example 1: Identity for a composed platform**
      A composition orders a service account, registers its definitions, and then orders this block as
      a child of the service account with their uuids. It orders the blocks that act as the account as
      children of this block.

      ## 📊 Shared Responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Provide the backplane identity used to create federations | ✅ | ❌ |
      | Choose the service account to federate | ❌ | ✅ |
      | Choose which building block definitions may act as the service account | ❌ | ✅ |
      EOT
    ))
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"

    # The run resolves the WIF issuer itself, so the caller passes plain definition uuids.
    permissions = [
      "INTEGRATION_LIST",
    ]

    implementation = {
      terraform = {
        terraform_version              = "1.12.5"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/stackit/service-account-federation/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      project_id = {
        display_name    = "STACKIT Project ID"
        description     = "STACKIT project the service account lives in."
        type            = "STRING"
        assignment_type = "PLATFORM_TENANT_ID"
      }

      STACKIT_SERVICE_ACCOUNT_EMAIL = {
        display_name    = "STACKIT Service Account Email"
        description     = "Email of the STACKIT service account the provider authenticates as via WIF."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(module.backplane.service_account_email)
      }

      STACKIT_USE_OIDC = {
        display_name    = "STACKIT Use OIDC"
        description     = "Enables OIDC-based WIF for the STACKIT provider."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode("1")
      }

      STACKIT_FEDERATED_TOKEN_FILE = {
        display_name    = "STACKIT Federated Token File"
        description     = "Path to the WIF token file injected by meshStack."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode("/var/run/secrets/workload-identity/azure/token")
      }

      automation_service_account_email = {
        display_name    = "Automation Service Account Email"
        description     = "Backplane identity the run acts as, as a regular input the configuration can read."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(module.backplane.service_account_email)
      }

      workspace_identifier = {
        display_name    = "Workspace Identifier"
        description     = "Workspace that owns the federated building block definitions."
        type            = "STRING"
        assignment_type = "WORKSPACE_IDENTIFIER"
      }

      service_account_email = {
        display_name    = "Service Account Email"
        description     = "Email of the STACKIT service account to federate, in the tenant's project."
        type            = "STRING"
        assignment_type = "USER_INPUT"
      }

      federated_building_block_definitions = {
        display_name    = "Federated Building Block Definitions"
        description     = "HCL list of building block definition UUIDs whose runs may act as the service account. They must be owned by the ordering workspace."
        type            = "CODE"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(jsonencode([]))
        # A composing architecture grows this list as it registers more definitions.
        updateable_by_consumer = true
      }
    }

    outputs = {
      service_account_email = {
        display_name    = "Service Account Email"
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
      version = ">= 0.21.0"
    }
    stackit = {
      source  = "stackitcloud/stackit"
      version = ">= 0.98.0, < 1.0.0"
    }
  }
}
