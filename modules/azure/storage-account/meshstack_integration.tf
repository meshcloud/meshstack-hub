variable "azure_tenant_id" {
  type        = string
  description = "Azure Entra tenant ID where storage accounts will be deployed."
}

variable "azure_subscription_id" {
  type        = string
  description = "Azure subscription ID where storage accounts will be deployed."
}

variable "azure_scope" {
  type        = string
  description = "Azure management group or subscription ID used for backplane role scope."
}

variable "azure_location" {
  type        = string
  default     = "germanywestcentral"
  description = "Default Azure region where storage accounts will be created."
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
  `bbd_draft`: If true, the building block definition version is kept in draft mode, which allows changing it (useful during development in LCF/ICF).
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
  source = "github.com/meshcloud/meshstack-hub//modules/azure/storage-account/backplane?ref=${var.hub.git_ref}"

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
    display_name             = coalesce(var.bbd_display_name, "Azure Storage Account")
    description              = coalesce(var.bbd_description, "Provisions an Azure Storage Account as a highly scalable, durable, and secure container in the target Azure subscription.")
    support_url              = "mailto:support@meshcloud.io"
    documentation_url        = "https://hub.meshcloud.io/platforms/azure/definitions/azure-storage-account"
    notification_subscribers = var.notification_subscribers
    symbol                   = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/main/modules/azure/storage-account/buildingblock/logo.png"
    target_type              = "WORKSPACE_LEVEL"

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
      This building block provisions an **Azure Storage Account** in your Azure subscription, providing scalable and durable cloud storage for blobs, files, queues, and tables.

      ## 🎯 When to use it

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
    ))
  }

  version_spec = {
    draft = var.hub.bbd_draft

    deletion_mode = "DELETE"

    implementation = {
      terraform = {
        terraform_version              = "1.12.5"
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
      ARM_SUBSCRIPTION_ID = {
        type            = "STRING"
        display_name    = "Azure Subscription ID"
        description     = "The Azure subscription ID where the storage account will be deployed."
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
        argument        = jsonencode(var.azure_location)
      }
      account_tier = {
        type              = "SINGLE_SELECT"
        display_name      = "Account Tier"
        description       = "Performance tier of the storage account. Premium only supports LRS/ZRS replication, so the Replication Type input is hidden and fixed to LRS when Premium is selected."
        assignment_type   = "USER_INPUT"
        selectable_values = ["Standard", "Premium"]
        default_value     = jsonencode("Standard")
      }
      account_replication_type = {
        type              = "SINGLE_SELECT"
        display_name      = "Replication Type"
        description       = "Only asked for while Account Tier is Standard; meshPanel hides it and meshStack sends no value for it when Premium is selected."
        assignment_type   = "USER_INPUT"
        selectable_values = ["LRS", "GRS", "RAGRS", "ZRS"]
        condition         = "input.account_tier == \"Standard\""
      }
      blob_soft_delete_retention_days = {
        type            = "INTEGER"
        display_name    = "Blob Soft-Delete Retention (Days)"
        description     = "Optional: leave blank to use the default 7-day blob soft-delete retention, or set your own retention period in days."
        assignment_type = "USER_INPUT"
        is_optional     = true
      }
      business_unit = {
        type            = "CODE"
        display_name    = "Business Unit"
        description     = "Value of the workspace's BusinessUnit tag, applied automatically as a tag on the storage account rather than typed in by a user."
        assignment_type = "TAG"
        argument        = jsonencode("WORKSPACE.BusinessUnit")
      }
      network_rules = {
        type            = "JSON"
        display_name    = "Network Rules"
        description     = "Restricts network access to the storage account, filled in through a meshPanel form rendered from the JSON Schema below."
        assignment_type = "USER_INPUT"
        json_schema = jsonencode({
          type     = "object"
          required = ["default_action"]
          properties = {
            default_action = {
              type = "string"
              enum = ["Allow", "Deny"]
            }
            bypass = {
              type = "array"
              items = {
                type = "string"
                enum = ["AzureServices", "Logging", "Metrics", "None"]
              }
            }
            ip_rules = {
              type  = "array"
              items = { type = "string" }
            }
            virtual_network_subnet_ids = {
              type  = "array"
              items = { type = "string" }
            }
          }
        })
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
      storage_account_url = {
        type            = "STRING"
        display_name    = "Open Storage Account"
        description     = "Azure Portal URL to the storage account"
        assignment_type = "RESOURCE_URL"
      }
      account_replication_type = {
        type            = "STRING"
        display_name    = "Replication Type"
        description     = "The replication type actually applied to the storage account."
        assignment_type = "NONE"
      }
      tags = {
        type            = "CODE"
        display_name    = "Tags"
        description     = "Tags actually applied to the storage account, including the resolved Cost Center tag."
        assignment_type = "NONE"
      }
      network_default_action = {
        type            = "STRING"
        display_name    = "Network Default Action"
        description     = "The default network action (Allow/Deny) actually applied to the storage account."
        assignment_type = "NONE"
      }
      blob_soft_delete_retention_days = {
        type            = "INTEGER"
        display_name    = "Blob Soft-Delete Retention (Days)"
        description     = "The blob soft-delete retention period actually applied, or null if left disabled."
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
      version = ">= 0.25.3"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.64, < 5.0.0"
    }
  }
}
