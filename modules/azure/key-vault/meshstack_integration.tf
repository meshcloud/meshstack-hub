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
  description = "Azure management group or subscription scope for backplane role assignment on landing zones."
}

variable "azure_hub_scope" {
  type        = string
  description = "Azure management group or subscription scope for the hub VNet peering role assignment."
}

variable "azure_location" {
  type        = string
  description = "Azure region for the UAMI resource."
}

variable "backplane_name" {
  type        = string
  default     = "azure-key-vault"
  description = "Name for the backplane resources (UAMI, role definition). Must match pattern ^[-a-z0-9]+$."
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
  # const       = true   # uncomment once OpenTofu ≥ 1.12 is available
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
  source = "github.com/meshcloud/meshstack-hub//modules/azure/key-vault/backplane?ref=${var.hub.git_ref}"

  name      = var.backplane_name
  scope     = var.azure_scope
  hub_scope = var.azure_hub_scope
  location  = var.azure_location

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
    display_name             = "Azure Key Vault"
    description              = "Provisions an Azure Key Vault with RBAC authorization and optional private endpoint connectivity for secure secret, key, and certificate management."
    support_url              = "mailto:support@meshcloud.io"
    documentation_url        = "https://hub.meshcloud.io/platforms/azure/definitions/azure-key-vault"
    notification_subscribers = var.notification_subscribers
    symbol                   = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/main/modules/azure/key-vault/buildingblock/logo.png"
    target_type              = "TENANT_LEVEL"
    supported_platforms      = [{ name = "AZURE" }]

    readme = chomp(<<-EOT
      Provisions an Azure Key Vault with RBAC authorization for secure storage and management of secrets, keys, and certificates. Supports optional private endpoint connectivity with hub VNet peering for network-isolated environments.

      ## When to use it

      Use this building block when your application team needs a dedicated Azure Key Vault to securely store and access secrets, API keys, certificates, or encryption keys — with consistent security defaults and optional private networking enforced across all projects.

      ## Usage Examples

      **Simple public Key Vault** — for development workloads where network isolation is not required:
      Deploy with the default settings. The Key Vault is created in the target subscription with RBAC authorization, soft delete, and purge protection enabled.

      **Private Key Vault with hub connectivity** — for production workloads requiring network isolation:
      Enable the private endpoint option and supply the hub VNet details. A private endpoint is created in the landing zone VNet, DNS is configured automatically, and bidirectional VNet peering connects to the hub network.

      ## Shared Responsibilities

      | Responsibility                              | Platform Team | Application Team |
      | ------------------------------------------- | :-----------: | :--------------: |
      | Set up backplane UAMI and role assignments  | ✅            | ❌               |
      | Define management group scope               | ✅            | ❌               |
      | Configure hub VNet for peering              | ✅            | ❌               |
      | Choose Key Vault name and Azure region      | ❌            | ✅               |
      | Enable / disable private endpoint           | ❌            | ✅               |
      | Grant RBAC roles to application identities  | ❌            | ✅               |
      | Store and rotate application secrets        | ❌            | ✅               |
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
        repository_path                = "modules/azure/key-vault/buildingblock"
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
        description     = "The Azure subscription ID in which the Key Vault will be created."
        assignment_type = "PLATFORM_TENANT_ID"
      }
      key_vault_name = {
        type            = "STRING"
        display_name    = "Key Vault Name"
        description     = "The name of the Key Vault. Must be globally unique, 3–24 characters, alphanumeric and dashes only."
        assignment_type = "USER_INPUT"
      }
      location = {
        type            = "STRING"
        display_name    = "Location"
        description     = "The Azure region where the Key Vault will be created (e.g. 'westeurope', 'eastus')."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("westeurope")
      }
      key_vault_resource_group_name = {
        type            = "STRING"
        display_name    = "Resource Group Name"
        description     = "The name of the resource group in which the Key Vault will be created."
        assignment_type = "USER_INPUT"
      }
    }

    outputs = {
      key_vault_id = {
        type            = "STRING"
        display_name    = "Key Vault ID"
        description     = "The Azure resource ID of the created Key Vault."
        assignment_type = "NONE"
      }
      key_vault_uri = {
        type            = "STRING"
        display_name    = "Key Vault URI"
        description     = "The URI of the Key Vault (e.g. https://my-vault.vault.azure.net/)."
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
      version = "~> 4.64.0"
    }
  }
}
