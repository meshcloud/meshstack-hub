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
  description = "Azure management group or subscription scope for landing zone role assignment."
}

variable "azure_hub_scope" {
  type        = string
  description = "Azure management group or subscription scope for hub VNet peering role assignment."
}

variable "azure_location" {
  type        = string
  description = "Azure region for the UAMI resource."
}

variable "backplane_name" {
  type        = string
  default     = "azure-aks"
  description = "Name for the backplane resources (UAMI, role definitions). Must match pattern ^[-a-z0-9]+$."
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
  # const       = true   # uncomment once OpenTofu >= 1.12 is available
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
  source = "github.com/meshcloud/meshstack-hub//modules/azure/aks/backplane?ref=${var.hub.git_ref}"

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
    display_name             = "Azure Kubernetes Service"
    description              = "Provisions a managed AKS cluster with optional private networking and hub VNet peering."
    support_url              = "mailto:support@meshcloud.io"
    documentation_url        = "https://hub.meshcloud.io/platforms/azure/definitions/azure-aks"
    notification_subscribers = var.notification_subscribers
    symbol                   = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/main/modules/azure/aks/buildingblock/logo.png"
    target_type              = "TENANT_LEVEL"
    supported_platforms      = [{ name = "AZURE" }]

    readme = chomp(<<-EOT
      This building block provisions a managed **Azure Kubernetes Service (AKS)** cluster in a target subscription, with full support for private clusters and hub VNet peering.

      The cluster is created in a dedicated resource group and virtual network. For private clusters, VNet peering between the landing zone and a hub subscription is configured automatically using a single UAMI with dual-scope role assignments.

      ## When to use it

      Use this building block when your application team needs a production-ready Kubernetes cluster on Azure with:
      - Consistent naming and networking conventions across all projects
      - Optional private API server endpoint (no public internet exposure)
      - Optional connectivity to a hub VNet for DNS resolution or egress routing
      - Automatic OIDC issuer and workload identity federation support

      ## Usage examples

      **Example 1 — Public cluster for a dev team:**
      Request this building block for your workspace. Provide a cluster name (e.g. `my-app-dev`) and choose a location. A public AKS cluster with a system node pool is created within minutes.

      **Example 2 — Private cluster connected to a hub:**
      Enable `private_cluster_enabled` and supply the hub VNet details (`hub_vnet_name`, `hub_resource_group_name`, `hub_subscription_id`). The backplane UAMI has the necessary peering permissions on both the landing zone and hub scopes.

      ## Shared Responsibilities

      | Responsibility                              | Platform Team | Application Team |
      | ------------------------------------------- | :-----------: | :--------------: |
      | Deploy and manage the backplane UAMI        | ✅            | ❌               |
      | Set management group / hub scope            | ✅            | ❌               |
      | Choose Azure region and cluster name        | ❌            | ✅               |
      | Configure node count and VM size            | ❌            | ✅               |
      | Enable private cluster and hub peering      | ❌            | ✅               |
      | Deploy workloads to the cluster             | ❌            | ✅               |
      | Manage Kubernetes RBAC and namespaces       | ❌            | ✅               |
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
        repository_path                = "modules/azure/aks/buildingblock"
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
        description     = "The Azure subscription ID in which the AKS cluster will be created."
        assignment_type = "PLATFORM_TENANT_ID"
      }
      resource_group_name = {
        type            = "STRING"
        display_name    = "Resource Group Name"
        description     = "Name of the resource group to create for the AKS cluster."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("aks-prod-rg")
      }
      aks_cluster_name = {
        type            = "STRING"
        display_name    = "AKS Cluster Name"
        description     = "Name of the AKS cluster (1–63 characters)."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("prod-aks")
      }
      location = {
        type            = "STRING"
        display_name    = "Location"
        description     = "Azure region where the AKS cluster will be deployed (e.g. 'westeurope')."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("westeurope")
      }
      kubernetes_version = {
        type            = "STRING"
        display_name    = "Kubernetes Version"
        description     = "Kubernetes version for the AKS cluster (e.g. '1.33.0')."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("1.33.0")
      }
      node_count = {
        type            = "INT"
        display_name    = "Node Count"
        description     = "Number of nodes in the default node pool."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(3)
      }
      vm_size = {
        type            = "STRING"
        display_name    = "VM Size"
        description     = "Azure VM size for the node pool (e.g. 'Standard_D2s_v3')."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("Standard_A2_v2")
      }
      private_cluster_enabled = {
        type            = "BOOL"
        display_name    = "Private Cluster"
        description     = "Enable private cluster mode (API server only accessible via private endpoint)."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(false)
      }
    }

    outputs = {
      oidc_issuer_url = {
        type            = "STRING"
        display_name    = "OIDC Issuer URL"
        description     = "OIDC issuer URL for federated identity and workload identity setup."
        assignment_type = "NONE"
      }
      subnet_id = {
        type            = "STRING"
        display_name    = "Subnet ID"
        description     = "Subnet ID used by the AKS cluster."
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
