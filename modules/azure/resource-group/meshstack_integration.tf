variable "azure_tenant_id" {
  type        = string
  description = "Azure Entra tenant ID used for provider authentication."
}

variable "azure_subscription_id" {
  type        = string
  description = "Azure subscription ID used for provider authentication of the backplane service principal."
}

variable "azure_scope" {
  type        = string
  description = "Azure management group or subscription scope for backplane role assignment."
}

variable "backplane_name" {
  type        = string
  default     = "azure-resource-group"
  description = "Name for the backplane resources (service principal, role definition). Must match pattern ^[-a-z0-9]+$."
}

variable "notification_subscribers" {
  type        = list(string)
  default     = []
  description = "List of email addresses to notify on building block lifecycle events."
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
  source = "./backplane"

  name  = var.backplane_name
  scope = var.azure_scope

  create_service_principal_name = var.backplane_name

  workload_identity_federation = {
    issuer  = data.meshstack_integrations.integrations.workload_identity_federation.replicator.issuer
    subject = "${trimsuffix(data.meshstack_integrations.integrations.workload_identity_federation.replicator.subject, ":replicator")}:workspace.${var.meshstack.owning_workspace_identifier}.buildingblockdefinition.${meshstack_building_block_definition.this.metadata.uuid}"
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name             = "Azure Resource Group"
    description              = "Creates an empty Azure Resource Group for a project. The resource group name is automatically generated as 'rg-<workspaceId>-<projectId>'."
    support_url              = "mailto:support@meshcloud.io"
    documentation_url        = "https://hub.meshcloud.io/platforms/azure/definitions/azure-resource-group"
    notification_subscribers = var.notification_subscribers
    symbol                   = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/main/modules/azure/resource-group/buildingblock/logo.png"
    target_type              = "TENANT_LEVEL"
    supported_platforms      = [{ name = "AZURE" }]

    readme = chomp(<<-EOT
      ## Azure Resource Group

      This building block provisions an empty **Azure Resource Group** in a target subscription.
      The resource group name is automatically derived from the meshStack context following the schema:

      ```
      rg-<workspaceIdentifier>-<projectIdentifier>
      ```

      ## When to use it?

      Use this building block when your application team needs a dedicated Azure Resource Group
      to deploy resources into, with a consistent naming convention enforced across all projects.

      ## Shared Responsibilities

      | Responsibility                          | Platform Team | Application Team |
      | --------------------------------------- | :-----------: | :--------------: |
      | Set up backplane service principal      | ✅            | ❌               |
      | Define management group scope           | ✅            | ❌               |
      | Choose Azure region (location)          | ❌            | ✅               |
      | Deploy resources into the group         | ❌            | ✅               |
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
        repository_path                = "modules/azure/resource-group/buildingblock"
        ref_name                       = var.hub.git_ref
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      ARM_CLIENT_ID = {
        type            = "STRING"
        display_name    = "ARM Client ID"
        description     = "Client ID of the service principal used to authenticate with Azure."
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(module.backplane.created_service_principal.client_id)
      }
      ARM_TENANT_ID = {
        type            = "STRING"
        display_name    = "ARM Tenant ID"
        description     = "Azure Entra tenant ID for authentication."
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(var.azure_tenant_id)
      }
      ARM_SUBSCRIPTION_ID = {
        type            = "STRING"
        display_name    = "ARM Subscription ID"
        description     = "The Azure subscription ID used for provider authentication."
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(var.azure_subscription_id)
      }
      ARM_USE_OIDC = {
        type            = "STRING"
        display_name    = "ARM Use OIDC"
        description     = "Enables OIDC-based workload identity federation for the Azure provider."
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode("true")
      }
      ARM_OIDC_TOKEN_FILE_PATH = {
        type            = "STRING"
        display_name    = "ARM OIDC Token File Path"
        description     = "Path to the OIDC token file used for workload identity federation authentication."
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode("/var/run/secrets/workload-identity/azure/token")
      }
      subscription_id = {
        type            = "STRING"
        display_name    = "Subscription ID"
        description     = "The Azure subscription ID in which the resource group will be created."
        assignment_type = "PLATFORM_TENANT_ID"
      }
      workspace_identifier = {
        type            = "STRING"
        display_name    = "Workspace Identifier"
        description     = "The meshStack workspace identifier. Used to generate the resource group name (rg-<workspaceId>-<projectId>)."
        assignment_type = "USER_INPUT"
      }
      project_identifier = {
        type            = "STRING"
        display_name    = "Project Identifier"
        description     = "The meshStack project identifier. Used to generate the resource group name (rg-<workspaceId>-<projectId>)."
        assignment_type = "USER_INPUT"
      }
      location = {
        type            = "STRING"
        display_name    = "Location"
        description     = "The Azure region where the resource group will be created (e.g. 'westeurope', 'eastus')."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("westeurope")
      }
    }

    outputs = {
      resource_group_name = {
        type            = "STRING"
        display_name    = "Resource Group Name"
        description     = "The name of the created resource group (e.g. 'rg-myworkspace-myproject')."
        assignment_type = "NONE"
      }
      resource_group_id = {
        type            = "STRING"
        display_name    = "Resource Group ID"
        description     = "The Azure resource ID of the created resource group."
        assignment_type = "NONE"
      }
    }
  }
}

terraform {
  required_version = ">= 1.11.0"

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = "~> 0.20.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.64"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.8"
    }
  }
}
