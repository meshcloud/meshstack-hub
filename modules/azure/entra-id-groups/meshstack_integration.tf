variable "azure_tenant_id" {
  type        = string
  description = "Azure Entra tenant ID where groups will be created."
}

variable "azure_scope" {
  type        = string
  description = "Azure management group or subscription ID used as the backplane UAMI's role assignment scope."
}

variable "azure_location" {
  type        = string
  description = "Azure region for the backplane resource group and UAMI (e.g. 'westeurope')."
}

variable "backplane_name" {
  type        = string
  default     = "azure-entra-id-groups"
  description = "Name for the backplane resources (resource group, UAMI, role definition). Must match pattern ^[-a-z0-9]+$."

  validation {
    condition     = can(regex("^[-a-z0-9]+$", var.backplane_name))
    error_message = "Only lowercase alphanumeric characters and dashes are allowed."
  }
}

variable "notification_subscribers" {
  type        = list(string)
  default     = []
  description = "Email addresses notified on building block lifecycle events."
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
  const       = true
  default     = {}
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

data "meshstack_integrations" "integrations" {}

module "backplane" {
  source   = "github.com/meshcloud/meshstack-hub//modules/azure/entra-id-groups/backplane?ref=${var.hub.git_ref}"
  name     = var.backplane_name
  scope    = var.azure_scope
  location = var.azure_location

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
    display_name             = "Azure Entra ID Groups"
    description              = "Creates Entra security groups for meshStack project roles, with optional Administrative Unit membership."
    support_url              = "mailto:support@meshcloud.io"
    documentation_url        = "https://hub.meshcloud.io/platforms/azure/definitions/azure-entra-id-groups"
    notification_subscribers = var.notification_subscribers
    symbol                   = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/main/modules/azure/entra-id-groups/buildingblock/logo.png"
    target_type              = "TENANT_LEVEL"

    readme = chomp(<<-EOT
      Automatically provision Entra ID security groups for every role in a meshStack project. Groups are named consistently using the workspace identifier, project identifier, an optional prefix, and the role name as suffix — giving your teams a predictable, auditable group structure in Azure Active Directory.

      ## When to use it

      Use this building block when you want to:
      - Map meshStack project roles (admin, user, reader, or custom roles) to Entra security groups for RBAC assignments in Azure.
      - Enforce a standard naming scheme across all projects in your platform.
      - Optionally scope groups inside a dedicated Entra Administrative Unit to isolate tenant-level identities from the rest of the directory.

      ## Usage examples

      **Default meshStack roles (admin / user / reader):**

      A project `my-project` in workspace `my-workspace` with prefix `plat` produces three groups:
      - `plat-my-workspace-my-project-admin`
      - `plat-my-workspace-my-project-user`
      - `plat-my-workspace-my-project-reader`

      **Custom roles:**

      Set *Project Roles* to `devops,qa,readonly` to create:
      - `plat-my-workspace-my-project-devops`
      - `plat-my-workspace-my-project-qa`
      - `plat-my-workspace-my-project-readonly`

      **With Administrative Unit:**

      Provide the object ID of an existing Entra Administrative Unit. All generated groups are added as members of that AU, restricting who can manage them in the directory.

      ## Shared Responsibilities

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Deploy and configure the backplane identity | ✅ | ❌ |
      | Define the group naming prefix | ✅ | ❌ |
      | Create and delete Entra groups | ✅ | ❌ |
      | Add the Administrative Unit (optional) | ✅ | ❌ |
      | Choose which project roles get groups | ❌ | ✅ |
      | Assign users to generated groups (automated via project membership) | ✅ | ❌ |
      | Manage which users have which project roles | ❌ | ✅ |
      | Use group IDs in downstream RBAC assignments | ❌ | ✅ |
    EOT
    )
  }

  version_spec = {
    draft = var.hub.bbd_draft

    deletion_mode = "DELETE"

    implementation = {
      terraform = {
        terraform_version              = "1.9.0"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/azure/entra-id-groups/buildingblock"
        ref_name                       = var.hub.git_ref
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      ARM_CLIENT_ID = {
        type            = "STRING"
        display_name    = "ARM Client ID"
        description     = "Client ID of the UAMI used to authenticate with Azure."
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(module.backplane.identity.client_id)
      }
      ARM_TENANT_ID = {
        type            = "STRING"
        display_name    = "ARM Tenant ID"
        description     = "Azure Entra tenant ID for authentication."
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(var.azure_tenant_id)
      }
      ARM_USE_OIDC = {
        type            = "STRING"
        display_name    = "ARM Use OIDC"
        description     = "Enables OIDC-based workload identity federation for the AzureAD provider."
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode("true")
      }
      ARM_OIDC_TOKEN_FILE_PATH = {
        type            = "STRING"
        display_name    = "ARM OIDC Token File Path"
        description     = "Path to the OIDC token file used for workload identity federation."
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode("/var/run/secrets/workload-identity/azure/token")
      }
      prefix = {
        type            = "STRING"
        display_name    = "Group Name Prefix"
        description     = "Optional prefix prepended to all group display names (e.g. 'plat'). Leave empty to omit."
        assignment_type = "USER_INPUT"
        argument        = jsonencode("")
      }
      workspace_identifier = {
        type            = "STRING"
        display_name    = "Workspace Identifier"
        description     = "meshStack workspace identifier. Injected automatically from the platform context."
        assignment_type = "PLATFORM_TENANT_WORKSPACE_IDENTIFIER"
      }
      project_identifier = {
        type            = "STRING"
        display_name    = "Project Identifier"
        description     = "meshStack project identifier. Injected automatically from the platform context."
        assignment_type = "PLATFORM_TENANT_PROJECT_IDENTIFIER"
      }
      project_roles = {
        type            = "STRING"
        display_name    = "Project Roles"
        description     = "Comma-separated list of project role name suffixes. One Entra group is created per role. Defaults to the three standard meshStack roles."
        assignment_type = "USER_INPUT"
        argument        = jsonencode("admin,user,reader")
      }
      administrative_unit_id = {
        type            = "STRING"
        display_name    = "Administrative Unit ID"
        description     = "Object ID of the Entra Administrative Unit to add the groups to. Leave empty to skip AU membership."
        assignment_type = "USER_INPUT"
        argument        = jsonencode("")
      }
      user_lookup_attribute = {
        type            = "STRING"
        display_name    = "User Lookup Attribute"
        description     = "Azure AD attribute used to look up users. 'upn' matches on User Principal Name; 'email' matches on the primary mail address."
        assignment_type = "STATIC"
        argument        = jsonencode("upn")
      }
      users = {
        type            = "CODE"
        display_name    = "Users"
        description     = "Project members from meshStack with their assigned roles. Injected automatically by meshStack."
        assignment_type = "USER_PERMISSIONS"
      }
    }

    outputs = {
      group_object_ids = {
        type            = "STRING"
        display_name    = "Group Object IDs"
        description     = "JSON map of project role name to Entra group object ID."
        assignment_type = "NONE"
      }
      group_display_names = {
        type            = "STRING"
        display_name    = "Group Display Names"
        description     = "JSON map of project role name to Entra group display name."
        assignment_type = "NONE"
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
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 3.8"
    }
  }
}
