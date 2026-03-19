variable "hub" {
  type = object({
    git_ref   = optional(string, "main")
    bbd_draft = optional(bool, true)
  })
  default     = {}
  description = <<-EOT
  `git_ref`: Hub release reference. Set to a tag (e.g. 'v1.2.3') or branch or commit sha of the meshstack-hub repo.
  `bbd_draft`: If true, the building block definition version is kept in draft mode, which allows changing it (useful during development in LCF/ICF).
  EOT
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
  })
  description = "`owning_workspace_identifier`: Identifier of the workspace that owns the building block."
}

# Retrieves the workload identity federation configuration from meshStack.
# The building block runners share the same OIDC issuer and namespace prefix as meshStack integrations.
# For self-hosted runners running outside our cluster, this does not hold true.
data "meshstack_integrations" "integrations" {}

variable "azure" {
  type = object({
    tenant_id       = string
    subscription_id = string
    scope           = string
    location        = optional(string, "germanywestcentral")
  })
  description = <<-EOT
  `tenant_id`: Azure Entra tenant ID where the storage accounts will be deployed.
  `subscription_id`: Azure subscription ID where storage accounts will be deployed.
  `scope`: Azure management group or subscription ID used as the scope for the backplane role definition and assignment.
  `location`: Default Azure region where storage accounts will be created (e.g. 'germanywestcentral').
  EOT
}

variable "backplane_name" {
  type        = string
  default     = "azure-storage-account"
  description = "Name for the backplane resources (service principal, role definition). Must match pattern ^[-a-z0-9]+$."
}

variable "notification_subscribers" {
  type        = list(string)
  default     = []
  description = "List of email addresses to notify on building block lifecycle events."
}

module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/azure/storage-account/backplane?ref=0a6d313e509e1c9052712f0d9c41c2d0a96f9a39"

  name  = var.backplane_name
  scope = var.azure.scope

  create_service_principal_name = var.backplane_name

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
  }

  spec = {
    display_name             = "Azure Storage Account"
    description              = "Provisions an Azure Storage Account as a highly scalable, durable, and secure container in the target Azure subscription."
    support_url              = "mailto:support@meshcloud.io"
    documentation_url        = "https://hub.meshcloud.io/platforms/azure/definitions/azure-storage-account"
    notification_subscribers = var.notification_subscribers
    symbol                   = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/main/modules/azure/storage-account/buildingblock/logo.png"
    target_type              = "WORKSPACE_LEVEL"

    readme = chomp(<<-EOT
      ## Azure Storage Account

      This building block provisions an **Azure Storage Account** in your Azure subscription, providing scalable and durable cloud storage for blobs, files, queues, and tables.

      ## When to use it?

      Use this building block when you need a managed Azure Storage Account with consistent naming, resource group organisation, and a pre-configured lifecycle policy.

      ## Shared Responsibilities

      | Responsibility                              | Platform Team | Application Team |
      | ------------------------------------------- | :-----------: | :--------------: |
      | Provision and configure storage account     | ✅            | ❌               |
      | Manage storage account lifecycle            | ✅            | ❌               |
      | Choose storage account name and region      | ❌            | ✅               |
      | Manage data stored in the storage account   | ❌            | ✅               |
      | Define access policies for stored data      | ❌            | ✅               |
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
        repository_path                = "modules/azure/storage-account/buildingblock"
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
        argument        = jsonencode(var.azure.tenant_id)
      }
      ARM_SUBSCRIPTION_ID = {
        type            = "STRING"
        display_name    = "Azure Subscription ID"
        description     = "The Azure subscription ID where the storage account will be deployed."
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(var.azure.subscription_id)
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
      storage_account_name = {
        type                           = "STRING"
        display_name                   = "Storage Account Name"
        description                    = "A name prefix for the storage account. A random 5-character suffix will be appended to ensure uniqueness (e.g. 'myapp' becomes 'myappx7k2q'). Only lowercase letters and numbers, 3–19 characters."
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[a-z0-9]{3,19}$"
        validation_regex_error_message = "Only lowercase letters and numbers are allowed, between 3 and 19 characters (a 5-character suffix will be appended, keeping the final name within Azure's 24-character limit)."
      }
      location = {
        type            = "STRING"
        display_name    = "Location"
        description     = "The Azure region where the storage account will be created."
        assignment_type = "STATIC"
        argument        = jsonencode(var.azure.location)
      }
    }

    outputs = {
      storage_account_id = {
        type            = "STRING"
        display_name    = "Storage Account ID"
        description     = "The Azure resource ID of the created storage account."
        assignment_type = "NONE"
      }
      storage_account_name = {
        type            = "STRING"
        display_name    = "Storage Account Name"
        description     = "The name of the created storage account."
        assignment_type = "NONE"
      }
      storage_account_resource_group = {
        type            = "STRING"
        display_name    = "Resource Group"
        description     = "The name of the resource group containing the storage account."
        assignment_type = "NONE"
      }
    }
  }
}

output "building_block_definition_version_uuid" {
  description = "UUID of the latest version. In draft mode returns the latest draft; otherwise returns the latest release."
  value       = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest.uuid : meshstack_building_block_definition.this.version_latest_release.uuid
}

terraform {
  required_version = ">= 1.11.0"

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = "~> 0.19.3"
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
