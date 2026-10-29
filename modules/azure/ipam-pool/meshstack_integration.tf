variable "azure_tenant_id" {
  type        = string
  description = "Azure Entra tenant ID used for provider authentication."
}

variable "azure_scope" {
  type        = string
  description = "Full resource path of the management group ('/providers/Microsoft.Management/managementGroups/<id>') or subscription ('/subscriptions/<guid>') the network manager governs. The deploy role is granted here too, so it must contain the subscription the pool is ordered into."
  validation {
    condition     = can(regex("^/subscriptions/[0-9a-fA-F-]{36}$|^/providers/Microsoft\\.Management/managementGroups/.+$", var.azure_scope))
    error_message = "Must be a full resource path: '/subscriptions/<guid>' or '/providers/Microsoft.Management/managementGroups/<id>', not a bare GUID."
  }
}

variable "azure_location" {
  type        = string
  default     = "germanywestcentral"
  description = "Azure region where the network manager and its IPAM pool are created."
}

variable "azure_resource_group_name" {
  type        = string
  default     = "ipam"
  description = "Name of the resource group created in the ordering subscription to host the network manager and its IPAM pool."
}

variable "azure_backplane_subscription_id" {
  type        = string
  description = "Subscription (bare GUID) where the backplane UAMI and its resource group are created."
  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.azure_backplane_subscription_id))
    error_message = "Must be a bare subscription GUID (e.g. '92eae5db-f627-4428-827f-9261eab6e7e7'), not a '/subscriptions/<guid>' path."
  }
}

variable "backplane_name" {
  type        = string
  default     = "azure-ipam-pool"
  description = "Name for the backplane resources (identity, resource group, role definition). Must match pattern ^[-a-z0-9]+$."
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

module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/azure/ipam-pool/backplane?ref=${var.hub.git_ref}"

  name            = var.backplane_name
  scope           = var.azure_scope
  location        = var.azure_location
  subscription_id = var.azure_backplane_subscription_id

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
    display_name             = coalesce(var.bbd_display_name, "Azure IPAM Pool")
    description              = coalesce(var.bbd_description, "Provides a central IP address pool that spoke networks draw non-overlapping address ranges from.")
    support_url              = "mailto:support@meshcloud.io"
    documentation_url        = "https://hub.meshcloud.io/platforms/azure/definitions/azure-ipam-pool"
    notification_subscribers = var.notification_subscribers
    symbol                   = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/main/modules/azure/ipam-pool/buildingblock/logo.png"
    target_type              = "TENANT_LEVEL"
    supported_platforms      = [{ name = "AZURE" }]

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
      This building block creates a central **IP address pool** in your Azure subscription. Virtual networks across your landing zones request a free, non-overlapping address range of a given size from it, instead of someone planning and tracking ranges by hand.

      ## 🎯 When to use it

      Use this building block when you:
      - run a hub-and-spoke network and want spoke address ranges handed out automatically
      - need an overview of which address ranges are allocated to which virtual network

      ## 💡 Usage examples

      **Example 1: Automatic spoke address space**
      A platform team orders the pool with `10.100.0.0/16` in its connectivity subscription. Every spoke network ordered afterwards gets the next free `/24` from it.

      **Example 2: Separate pools per environment**
      A platform team orders one pool for production and one for development landing zones, so both environments never compete for the same ranges.

      ## 📊 Shared Responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Provision the network manager and the IPAM pool | ✅ | ❌ |
      | Choose the pool's address range so it does not overlap on-premise networks | ✅ | ❌ |
      | Grant consuming building blocks access to the pool | ✅ | ❌ |
      | Request address space of the right size for a workload | ❌ | ✅ |
    EOT
    ))
  }

  version_spec = {
    draft = var.hub.bbd_draft

    deletion_mode = "DELETE"
    runner_ref    = var.meshstack.runner_ref

    implementation = {
      terraform = {
        terraform_version              = "1.12.5"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/azure/ipam-pool/buildingblock"
        ref_name                       = var.hub.git_ref
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      ARM_CLIENT_ID = {
        type            = "STRING"
        display_name    = "ARM Client ID"
        description     = "Client ID of the managed identity used to authenticate with Azure."
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
        description     = "The Azure subscription that hosts the network manager and its IPAM pool."
        assignment_type = "PLATFORM_TENANT_ID"
      }
      location = {
        type            = "STRING"
        display_name    = "Location"
        description     = "The Azure region where the network manager and its IPAM pool are created."
        assignment_type = "STATIC"
        argument        = jsonencode(var.azure_location)
      }
      resource_group_name = {
        type            = "STRING"
        display_name    = "Resource Group"
        description     = "Name of the resource group that hosts the network manager and its IPAM pool."
        assignment_type = "STATIC"
        argument        = jsonencode(var.azure_resource_group_name)
      }
      network_manager_scope = {
        type            = "STRING"
        display_name    = "Network Manager Scope"
        description     = "Management group or subscription whose virtual networks can draw address space from the pool."
        assignment_type = "STATIC"
        argument        = jsonencode(var.azure_scope)
      }
      name = {
        type                           = "STRING"
        display_name                   = "Pool Name"
        description                    = "Name of the IPAM pool, e.g. 'spokes-prod'."
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[a-z0-9][-a-z0-9]{1,40}$"
        validation_regex_error_message = "Only lowercase letters, numbers and dashes are allowed (2–41 characters, must start with a letter or number)."
      }
      address_prefix = {
        type                           = "STRING"
        display_name                   = "Address Range"
        description                    = "Address range of the pool in CIDR notation, e.g. '10.100.0.0/16'. Choose a range that does not overlap on-premise networks."
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$"
        validation_regex_error_message = "Address range must be a valid IPv4 CIDR range, e.g. '10.100.0.0/16'."
      }
    }

    outputs = {
      ipam_pool_id = {
        type            = "STRING"
        display_name    = "IPAM Pool ID"
        description     = "The resource ID of the IPAM pool. Set it as azure_ipam_pool_id of the spoke network building block definition."
        assignment_type = "NONE"
      }
      network_manager_id = {
        type            = "STRING"
        display_name    = "Network Manager ID"
        description     = "The resource ID of the network manager hosting the pool."
        assignment_type = "NONE"
      }
      address_prefix = {
        type            = "STRING"
        display_name    = "Address Range"
        description     = "The address range the pool hands out."
        assignment_type = "NONE"
      }
      summary = {
        type            = "STRING"
        display_name    = "Summary"
        description     = "Markdown summary of the created IPAM pool."
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
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.37.0, < 5.0.0"
    }
  }
}
