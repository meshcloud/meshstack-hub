variable "azure_tenant_id" {
  type        = string
  description = "Azure Entra tenant ID the landing zone subscriptions belong to."
}

variable "azure_scope" {
  type        = string
  description = "RBAC scope where the deploy role is granted: a management group ('/providers/Microsoft.Management/managementGroups/<id>') or a subscription ('/subscriptions/<guid>'), typically the parent of all landing zones."
  validation {
    condition     = can(regex("^/subscriptions/[0-9a-fA-F-]{36}$|^/providers/Microsoft\\.Management/managementGroups/.+$", var.azure_scope))
    error_message = "Must be a full resource path: '/subscriptions/<guid>' or '/providers/Microsoft.Management/managementGroups/<id>', not a bare GUID."
  }
}

variable "azure_location" {
  type        = string
  default     = "germanywestcentral"
  description = "Azure region of the backplane identity and of every Key Vault."
}

variable "azure_hub_scope" {
  type        = string
  default     = null
  description = "RBAC scope holding the hub vnet, as a full resource path like `azure_scope`. Set it together with the other `azure_hub_*` variables to let private Key Vaults peer into the hub."
  validation {
    condition     = var.azure_hub_scope == null || can(regex("^/subscriptions/[0-9a-fA-F-]{36}$|^/providers/Microsoft\\.Management/managementGroups/.+$", var.azure_hub_scope))
    error_message = "Must be a full resource path: '/subscriptions/<guid>' or '/providers/Microsoft.Management/managementGroups/<id>', not a bare GUID."
  }
}

variable "azure_hub_subscription_id" {
  type        = string
  default     = null
  description = "Subscription (bare GUID) of the hub vnet."
}

variable "azure_hub_resource_group_name" {
  type        = string
  default     = null
  description = "Resource group of the hub vnet."
}

variable "azure_hub_vnet_name" {
  type        = string
  default     = null
  description = "Name of the hub vnet that private Key Vaults peer into."
}

variable "backplane_name" {
  type        = string
  default     = "azure-key-vault"
  description = "Name for the backplane resources (identity, resource group, role definitions). Must match pattern ^[-a-z0-9]+$."
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

variable "bbd_schedule" {
  type = object({
    mode               = string
    frequency          = string
    automatic_approval = optional(bool)
  })
  default     = null
  description = <<-EOT
  Drift schedule for the building blocks of this definition, e.g. `{ mode = "DRIFT_RECONCILIATION", frequency = "DAILY", automatic_approval = true }` to revert manual changes to a Key Vault every day. `DRIFT_DETECTION` only reports drift. Null runs no schedule.
  EOT
}

variable "building_block_runner_uuid" {
  type        = string
  default     = null
  description = "Runs this building block on the given meshStack building block runner instead of the shared one meshStack hosts."
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
  hub_peering_enabled = var.azure_hub_vnet_name != null

  # The building block appends "-" and 5 random characters; Key Vault names allow 24 at most.
  key_vault_name_regex = "^[a-zA-Z][a-zA-Z0-9-]{1,16}[a-zA-Z0-9]$"
}

module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/azure/key-vault/backplane?ref=${var.hub.git_ref}"

  name      = var.backplane_name
  scope     = var.azure_scope
  hub_scope = var.azure_hub_scope
  location  = var.azure_location

  workload_identity_federation = {
    issuer   = meshstack_building_block_definition.this.version_latest.workload_identity_federation.issuer
    subjects = [meshstack_building_block_definition.this.version_latest.workload_identity_federation.subject]
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name             = coalesce(var.bbd_display_name, "Azure Key Vault")
    description              = coalesce(var.bbd_description, "Provides an Azure Key Vault in your subscription for secrets, keys and certificates, with RBAC authorization and optional private endpoint.")
    support_url              = "mailto:support@meshcloud.io"
    documentation_url        = "https://hub.meshcloud.io/platforms/azure/definitions/azure-key-vault"
    notification_subscribers = var.notification_subscribers
    symbol                   = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/azure/key-vault/buildingblock/logo.png"
    target_type              = "TENANT_LEVEL"
    supported_platforms      = [{ name = "AZURE" }]
    run_transparency         = true
    schedule                 = var.bbd_schedule

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
      This building block provisions an **Azure Key Vault** in your Azure subscription to store and manage secrets, keys and certificates. Access is controlled with Azure RBAC, and soft delete and purge protection are always on.

      ## 🎯 When to use it

      Use this building block when you:
      - Need a place for API keys, connection strings or certificates instead of keeping them in code or pipeline variables.
      - Want your applications to read secrets with their managed identity.
      - Need a vault that is reachable only from your private network.

      ## 💡 Usage examples

      **Example 1: Database credentials for an App Service**
      A team stores its database password in the vault and references it from the App Service configuration as `@Microsoft.KeyVault(VaultName=<vault>;SecretName=DatabasePassword)`.

      **Example 2: A private vault for production**
      A team enables the private endpoint, so the vault resolves to a private IP and is reachable only from the connected network.

      ## 🔐 Access

      The vault uses RBAC authorization, and nobody has data access when it is created. Grant yourself or your application a role such as `Key Vault Secrets Officer` or `Key Vault Secrets User` on the vault before reading or writing secrets.

      A deleted vault stays recoverable for 7 days and cannot be purged earlier, so its name stays reserved for that time.

      ## 📊 Shared Responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Provision the Key Vault with secure defaults | ✅ | ❌ |
      | Provide network connectivity to the hub | ✅ | ❌ |
      | Keep the vault's configuration as ordered | ✅ | ❌ |
      | Grant data access roles on the vault | ❌ | ✅ |
      | Store, rotate and retire secrets, keys and certificates | ❌ | ✅ |
      | Integrate the vault with applications | ❌ | ✅ |
    EOT
    ))
  }

  version_spec = {
    draft = var.hub.bbd_draft

    deletion_mode = "DELETE"
    runner_ref = var.building_block_runner_uuid == null ? null : {
      kind = "meshBuildingBlockRunner"
      uuid = var.building_block_runner_uuid
    }

    implementation = {
      terraform = {
        terraform_version              = "1.12.5"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/azure/key-vault/buildingblock"
        ref_name                       = var.hub.git_ref
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = merge({
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
        description     = "The Azure subscription the Key Vault is created in."
        assignment_type = "PLATFORM_TENANT_ID"
      }
      location = {
        type            = "STRING"
        display_name    = "Location"
        description     = "The Azure region the Key Vault is created in."
        assignment_type = "STATIC"
        argument        = jsonencode(var.azure_location)
      }
      key_vault_name = {
        type                           = "STRING"
        display_name                   = "Key Vault Name"
        description                    = "Name prefix of the Key Vault. A random 5-character suffix is appended for global uniqueness (e.g. 'payments' becomes 'payments-x7k2q')."
        assignment_type                = "USER_INPUT"
        value_validation_regex         = local.key_vault_name_regex
        validation_regex_error_message = "3 to 18 characters: letters, digits and dashes, starting with a letter and ending with a letter or digit."
        display_order                  = 1
      }
      key_vault_resource_group_name = {
        type                           = "STRING"
        display_name                   = "Resource Group Name"
        description                    = "Resource group the building block creates for the Key Vault. It is deleted with the building block."
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[-\\w\\._\\(\\)]{1,90}$"
        validation_regex_error_message = "1 to 90 characters: letters, digits, underscores, dashes, periods and parentheses."
        display_order                  = 2
      }
      public_network_access_enabled = {
        type            = "BOOLEAN"
        display_name    = "Public Network Access"
        description     = "Allow access to the vault from the public internet. RBAC still decides who may read secrets."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(false)
        display_order   = 3
      }
      private_endpoint_enabled = {
        type            = "BOOLEAN"
        display_name    = "Private Endpoint"
        description     = "Create a private endpoint in a new vnet, so the vault resolves to a private IP.${local.hub_peering_enabled ? " The vnet is peered into the hub." : ""}"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(false)
        display_order   = 4
      }
      vnet_address_space = {
        type            = "STRING"
        display_name    = "VNet Address Space"
        description     = "Address space of the new vnet holding the private endpoint. Must not overlap with the hub or other peered networks."
        assignment_type = "USER_INPUT"
        condition       = "input.private_endpoint_enabled == true"
        default_value   = jsonencode("10.250.0.0/16")
        display_order   = 5
      }
      subnet_address_prefix = {
        type            = "STRING"
        display_name    = "Subnet Address Prefix"
        description     = "Address prefix of the private endpoint subnet, within the vnet address space."
        assignment_type = "USER_INPUT"
        condition       = "input.private_endpoint_enabled == true"
        default_value   = jsonencode("10.250.1.0/24")
        display_order   = 6
      }
      },
      local.hub_peering_enabled ? {
        hub_subscription_id = {
          type            = "STRING"
          display_name    = "Hub Subscription ID"
          assignment_type = "STATIC"
          argument        = jsonencode(var.azure_hub_subscription_id)
        }
        hub_resource_group_name = {
          type            = "STRING"
          display_name    = "Hub Resource Group"
          assignment_type = "STATIC"
          argument        = jsonencode(var.azure_hub_resource_group_name)
        }
        hub_vnet_name = {
          type            = "STRING"
          display_name    = "Hub VNet"
          assignment_type = "STATIC"
          argument        = jsonencode(var.azure_hub_vnet_name)
        }
      } : {}
    )

    outputs = {
      key_vault_id = {
        type            = "STRING"
        display_name    = "Key Vault ID"
        description     = "The Azure resource ID of the Key Vault."
        assignment_type = "NONE"
      }
      key_vault_name = {
        type            = "STRING"
        display_name    = "Key Vault Name"
        description     = "The name of the Key Vault, including its random suffix."
        assignment_type = "NONE"
      }
      key_vault_uri = {
        type            = "STRING"
        display_name    = "Key Vault URI"
        description     = "The URI applications use to reach the Key Vault."
        assignment_type = "NONE"
      }
      key_vault_resource_group = {
        type            = "STRING"
        display_name    = "Resource Group"
        description     = "The resource group containing the Key Vault."
        assignment_type = "NONE"
      }
      key_vault_portal_url = {
        type            = "STRING"
        display_name    = "Open Key Vault"
        description     = "Azure Portal URL of the Key Vault."
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
      version = ">= 0.26.2"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.65.0, < 5.0.0"
    }
  }
}
