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
  description = "Azure region of the backplane identity and of every container registry."
}

variable "azure_hub_scope" {
  type        = string
  default     = null
  description = "RBAC scope holding the hub vnet, as a full resource path like `azure_scope`. Set it together with the other `azure_hub_*` variables to let private registries peer into the hub."
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
  description = "Name of the hub vnet that private registries peer into."
}

variable "backplane_name" {
  type        = string
  default     = "azure-container-registry"
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

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    tags                        = optional(map(list(string)), {})
    runner_ref = optional(object({
      kind = string
      uuid = string
    }))
    additional_trusted_runner_refs = optional(list(object({
      kind = string
      uuid = string
    })), [])
    supported_platforms = optional(list(object({
      kind = optional(string)
      name = optional(string)
      uuid = optional(string)
    })), [{ name = "AZURE" }])
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
  `bbd_draft`: If true, the building block definition version is kept in draft mode.
  EOT
}

# Lookup specified runner for workload identity federation info. Null results in the default hosted runner.
module "runner" {
  source = "github.com/meshcloud/meshstack-hub//modules/meshstack/runner-identity?ref=${var.hub.git_ref}"

  cloud                          = "azure"
  runner_ref                     = var.meshstack.runner_ref
  additional_trusted_runner_refs = var.meshstack.additional_trusted_runner_refs
  versions                       = meshstack_building_block_definition.this.versions
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
}

module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/azure/container-registry/backplane?ref=${var.hub.git_ref}"

  name      = var.backplane_name
  scope     = var.azure_scope
  hub_scope = var.azure_hub_scope
  location  = var.azure_location

  workload_identity_federation = {
    issuer   = module.runner.issuer
    audience = module.runner.audience
    subjects = [meshstack_building_block_definition.this.version_latest.workload_identity_federation.subject]
  }

  trusted_runner_identities = module.runner.trusted_identities
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name             = coalesce(var.bbd_display_name, "Azure Container Registry")
    description              = coalesce(var.bbd_description, "Provides an Azure Container Registry in your subscription for Docker images, Helm charts and other OCI artifacts, with an optional private endpoint.")
    support_url              = "mailto:support@meshcloud.io"
    documentation_url        = "https://hub.meshcloud.io/platforms/azure/definitions/azure-container-registry"
    notification_subscribers = var.notification_subscribers
    symbol                   = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/azure/container-registry/buildingblock/logo.png"
    target_type              = "TENANT_LEVEL"
    supported_platforms      = var.meshstack.supported_platforms
    run_transparency         = true

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
      This building block creates an **Azure Container Registry** (ACR) in your Azure subscription. You store Docker images, Helm charts and other OCI artifacts in it, and you log in with your Entra ID account.

      ## 🎯 When to use it

      Use this building block when you:
      - Need a private registry for the images your pipelines build.
      - Deploy containers to AKS, App Service or Container Apps and want to pull images with a managed identity.
      - Need a registry that is reachable only from your private network (Premium SKU).

      ## 💡 Usage examples

      **Example 1: Images for a microservice**
      Your CI pipeline builds an image, runs `az acr login` and pushes it as `<registry>.azurecr.io/orders:1.4.0`. Your AKS cluster pulls it from there.

      **Example 2: A private registry for production**
      You order the Premium SKU with a private endpoint, so the registry resolves to a private IP and is reachable only from the connected network.

      ## 🔐 Access

      Nobody can push or pull when the registry is created. Grant yourself or your pipeline the `AcrPush` role, and your workloads the `AcrPull` role, on the registry.

      ## 📊 Shared Responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Provision the registry with secure defaults | ✅ | ❌ |
      | Provide network connectivity to the hub | ✅ | ❌ |
      | Grant push and pull roles on the registry | ❌ | ✅ |
      | Push, tag and clean up images | ❌ | ✅ |
      | Scan images for vulnerabilities | ❌ | ✅ |
    EOT
    ))
  }

  version_spec = {
    draft = var.hub.bbd_draft

    deletion_mode = "DELETE"
    runner_ref    = module.runner.ref

    implementation = {
      terraform = {
        terraform_version              = "1.12.5"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/azure/container-registry/buildingblock"
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
        argument        = jsonencode(module.runner.token_path)
      }
      acr_name = {
        type                           = "STRING"
        display_name                   = "Registry Name"
        description                    = "Name prefix of the registry. A random 4-character suffix is appended for global uniqueness (e.g. 'payments' becomes 'paymentsx7k2')."
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[a-zA-Z0-9]{5,46}$"
        validation_regex_error_message = "5 to 46 characters: letters and digits only."
        display_order                  = 1
      }
      resource_group_name = {
        type                           = "STRING"
        display_name                   = "Resource Group Name"
        description                    = "Resource group the building block creates for the registry. It is deleted with the building block."
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[-\\w\\._\\(\\)]{1,90}$"
        validation_regex_error_message = "1 to 90 characters: letters, digits, underscores, dashes, periods and parentheses."
        display_order                  = 2
      }
      sku = {
        type              = "SINGLE_SELECT"
        display_name      = "SKU"
        description       = "Service tier of the registry. Basic and Standard differ in storage and throughput. Premium adds private endpoints, zone redundancy and a retention policy for untagged manifests."
        assignment_type   = "USER_INPUT"
        selectable_values = ["Basic", "Standard", "Premium"]
        default_value     = jsonencode("Standard")
        display_order     = 3
      }
      private_endpoint_enabled = {
        type            = "BOOLEAN"
        display_name    = "Private Endpoint"
        description     = "Create a private endpoint in a new vnet, so the registry resolves to a private IP. Needs the Premium SKU; other SKUs ignore it.${local.hub_peering_enabled ? " The vnet is peered into the hub." : ""}"
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
      subscription_id = {
        type            = "STRING"
        display_name    = "Subscription ID"
        description     = "The Azure subscription the registry is created in."
        assignment_type = "PLATFORM_TENANT_ID"
      }
      location = {
        type            = "STRING"
        display_name    = "Location"
        description     = "The Azure region the registry is created in."
        assignment_type = "STATIC"
        argument        = jsonencode(var.azure_location)
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
      acr_id = {
        type            = "STRING"
        display_name    = "Registry ID"
        description     = "The Azure resource ID of the registry."
        assignment_type = "NONE"
      }
      acr_name = {
        type            = "STRING"
        display_name    = "Registry Name"
        description     = "The name of the registry, including its random suffix."
        assignment_type = "NONE"
      }
      acr_login_server = {
        type            = "STRING"
        display_name    = "Login Server"
        description     = "The host name to log in to and to tag images with, e.g. 'myregistry.azurecr.io'."
        assignment_type = "NONE"
      }
      resource_group_name = {
        type            = "STRING"
        display_name    = "Resource Group"
        description     = "The resource group containing the registry."
        assignment_type = "NONE"
      }
      acr_portal_url = {
        type            = "STRING"
        display_name    = "Open Registry"
        description     = "Azure Portal URL of the registry."
        assignment_type = "RESOURCE_URL"
      }
      summary = {
        type            = "STRING"
        display_name    = "Summary"
        description     = "A markdown summary of the registry and how to push to it."
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
      version = ">= 0.27.2"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.65.0, < 5.0.0"
    }
  }
}
