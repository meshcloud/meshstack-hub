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
  description = "Azure region of the backplane identity and of every AKS cluster."
}

variable "azure_hub_scope" {
  type        = string
  default     = null
  description = "RBAC scope holding the hub vnet, as a full resource path like `azure_scope`. Set it together with the other `azure_hub_*` variables to let private clusters peer into the hub."
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
  description = "Name of the hub vnet that private clusters peer into."
}

variable "backplane_name" {
  type        = string
  default     = "azure-aks"
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
  source = "github.com/meshcloud/meshstack-hub//modules/azure/aks/backplane?ref=${var.hub.git_ref}"

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
    display_name             = coalesce(var.bbd_display_name, "Azure Kubernetes Service")
    description              = coalesce(var.bbd_description, "Provides an AKS cluster in your subscription with its own vnet, workload identity and an optional private API server.")
    support_url              = "mailto:support@meshcloud.io"
    documentation_url        = "https://hub.meshcloud.io/platforms/azure/definitions/azure-aks"
    notification_subscribers = var.notification_subscribers
    symbol                   = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/azure/aks/buildingblock/logo.png"
    target_type              = "TENANT_LEVEL"
    supported_platforms      = var.meshstack.supported_platforms
    run_transparency         = true

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
      This building block creates an **Azure Kubernetes Service (AKS)** cluster in your Azure subscription. The cluster gets its own resource group and vnet, Azure RBAC, an OIDC issuer and workload identity. You choose the node size and count, and whether the API server is public or private.

      ## 🎯 When to use it

      Use this building block when you:
      - Want to run containers on Kubernetes without building the cluster yourself.
      - Need workload identity, so your pods reach Azure services without secrets.
      - Need a cluster whose API server is reachable only from your private network.

      ## 💡 Usage examples

      **Example 1: A cluster for a development team**
      A team orders a public cluster with 2 nodes, runs `az aks get-credentials` and deploys its services with Helm.

      **Example 2: A private cluster for production**
      A team orders a private cluster. Its API server has only a private IP${local.hub_peering_enabled ? ", and its vnet is peered into the hub, so the team reaches it from the corporate network" : ""}.

      ## 🔐 Access

      Get the credentials with `az aks get-credentials --resource-group <resource group> --name <cluster name>`. You need a role on the cluster, such as `Azure Kubernetes Service Cluster User Role`, to do that.

      ## 📊 Shared Responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Provision the cluster, its vnet and its identity | ✅ | ❌ |
      | Provide network connectivity to the hub | ✅ | ❌ |
      | Choose node size, node count and Kubernetes version | ❌ | ✅ |
      | Upgrade Kubernetes and the node images | ❌ | ✅ |
      | Deploy and secure workloads in the cluster | ❌ | ✅ |
      | Grant cluster access to team members | ❌ | ✅ |
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
        repository_path                = "modules/azure/aks/buildingblock"
        ref_name                       = var.hub.git_ref
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = merge({
      aks_cluster_name = {
        type                           = "STRING"
        display_name                   = "Cluster Name"
        description                    = "Name of the AKS cluster."
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[a-zA-Z0-9][a-zA-Z0-9_-]{0,61}[a-zA-Z0-9]$"
        validation_regex_error_message = "2 to 63 characters: letters, digits, underscores and dashes, starting and ending with a letter or digit."
        display_order                  = 1
      }
      resource_group_name = {
        type                           = "STRING"
        display_name                   = "Resource Group Name"
        description                    = "Resource group the building block creates for the cluster. It is deleted with the building block."
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[-\\w\\._\\(\\)]{1,90}$"
        validation_regex_error_message = "1 to 90 characters: letters, digits, underscores, dashes, periods and parentheses."
        display_order                  = 2
      }
      dns_prefix = {
        type                           = "STRING"
        display_name                   = "DNS Prefix"
        description                    = "Prefix of the API server host name."
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[a-z0-9][a-z0-9-]{0,53}[a-z0-9]$"
        validation_regex_error_message = "2 to 55 characters: lowercase letters, digits and dashes, starting and ending with a letter or digit."
        display_order                  = 3
      }
      node_count = {
        type            = "INTEGER"
        display_name    = "Node Count"
        description     = "Number of nodes in the default node pool."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(3)
        display_order   = 4
      }
      vm_size = {
        type            = "STRING"
        display_name    = "Node Size"
        description     = "Azure VM size of the nodes. A node needs at least 2 vCPUs and 4 GiB of memory."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("Standard_D2s_v6")
        display_order   = 5
      }
      kubernetes_version = {
        type                           = "STRING"
        display_name                   = "Kubernetes Version"
        description                    = "Kubernetes version, e.g. 1.34. Leave it empty to get the version AKS recommends."
        assignment_type                = "USER_INPUT"
        is_optional                    = true
        value_validation_regex         = "^[0-9]+\\.[0-9]+(\\.[0-9]+)?$"
        validation_regex_error_message = "X.Y or X.Y.Z, e.g. 1.34 or 1.34.2."
        display_order                  = 6
      }
      private_cluster_enabled = {
        type            = "BOOLEAN"
        display_name    = "Private Cluster"
        description     = "Give the API server only a private IP.${local.hub_peering_enabled ? " The cluster vnet is peered into the hub." : ""}"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(false)
        display_order   = 7
      }
      vnet_address_space = {
        type            = "STRING"
        display_name    = "VNet Address Space"
        description     = "Address space of the cluster vnet. Must not overlap with the hub or other peered networks."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("10.240.0.0/16")
        display_order   = 8
      }
      subnet_address_prefix = {
        type            = "STRING"
        display_name    = "Subnet Address Prefix"
        description     = "Address prefix of the node subnet, within the vnet address space."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("10.240.0.0/20")
        display_order   = 9
      }
      subscription_id = {
        type            = "STRING"
        display_name    = "Subscription ID"
        description     = "The Azure subscription the cluster is created in."
        assignment_type = "PLATFORM_TENANT_ID"
      }
      location = {
        type            = "STRING"
        display_name    = "Location"
        description     = "The Azure region the cluster is created in."
        assignment_type = "STATIC"
        argument        = jsonencode(var.azure_location)
      }
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
      },
      local.hub_peering_enabled ? {
        hub_subscription_id = {
          type            = "STRING"
          display_name    = "Hub Subscription ID"
          assignment_type = "STATIC"
          is_optional     = true
          argument        = jsonencode(var.azure_hub_subscription_id)
        }
        hub_resource_group_name = {
          type            = "STRING"
          display_name    = "Hub Resource Group"
          assignment_type = "STATIC"
          is_optional     = true
          argument        = jsonencode(var.azure_hub_resource_group_name)
        }
        hub_vnet_name = {
          type            = "STRING"
          display_name    = "Hub VNet"
          assignment_type = "STATIC"
          is_optional     = true
          argument        = jsonencode(var.azure_hub_vnet_name)
        }
      } : {}
    )

    outputs = {
      aks_cluster_name = {
        type            = "STRING"
        display_name    = "Cluster Name"
        description     = "The name of the AKS cluster."
        assignment_type = "NONE"
      }
      aks_cluster_id = {
        type            = "STRING"
        display_name    = "Cluster ID"
        description     = "The Azure resource ID of the AKS cluster."
        assignment_type = "NONE"
      }
      resource_group_name = {
        type            = "STRING"
        display_name    = "Resource Group"
        description     = "The resource group containing the cluster."
        assignment_type = "NONE"
      }
      kube_api_server_fqdn = {
        type            = "STRING"
        display_name    = "API Server"
        description     = "Host name of the Kubernetes API server, the private one for a private cluster."
        assignment_type = "NONE"
      }
      oidc_issuer_url = {
        type            = "STRING"
        display_name    = "OIDC Issuer URL"
        description     = "Issuer URL to federate Azure identities with Kubernetes service accounts."
        assignment_type = "NONE"
      }
      aks_portal_url = {
        type            = "STRING"
        display_name    = "Open AKS Cluster"
        description     = "Azure Portal URL of the AKS cluster."
        assignment_type = "RESOURCE_URL"
      }
      summary = {
        type            = "STRING"
        display_name    = "Summary"
        description     = "Markdown summary of the cluster and how to get its credentials."
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
