

variable "azure_tenant_id" {
  type        = string
  description = "Azure Entra tenant ID where the spoke network and hub live."

}

# variable "azure_subscription_id" {
#   type        = string
#   description = "Azure subscription ID of the spoke landing zone where the vnet is created."
# }

variable "azure_hub_subscription_id" {
  type        = string
  description = "PROVIDER TARGET: hub subscription the azurerm provider reads the hub vnet from and creates the hub-side peering in. Bare GUID (e.g. '92eae5db-...'), NOT a '/subscriptions/...' path. Same sub as azure_hub_scope in a simple setup, but different format/purpose (that one is the RBAC scope)."

}

variable "azure_scope" {
  type        = string
  description = "RBAC SCOPE: where the spoke deploy role is granted. Full resource path — a management group ('/providers/Microsoft.Management/managementGroups/<id>') or a subscription ('/subscriptions/<guid>'). Typically the parent of all landing zones. Not to be confused with azure_subscription_id (the provider target GUID)."

}

variable "azure_hub_scope" {
  type        = string
  description = "RBAC SCOPE: where the hub peering role is granted. Full resource path — a management group ('/providers/Microsoft.Management/managementGroups/<id>') or a subscription ('/subscriptions/<guid>') containing the hub vnet. Same sub as azure_hub_subscription_id in a simple setup, but this is the full path (RBAC scope), that one is the bare GUID (provider target)."

}

variable "azure_location" {
  type        = string
  default     = "germanywestcentral"
  description = "Default Azure region where the spoke resource group and vnet are created."
}

variable "azure_hub_resource_group_name" {
  type        = string
  description = "Name of the resource group that contains the hub vnet to peer into."

}

variable "azure_hub_vnet_name" {
  type        = string
  description = "Name of the hub vnet to peer the spoke into."


}

variable "azure_spoke_resource_group_name" {
  type        = string
  default     = "connectivity"
  description = "Name of the resource group created in the spoke subscription to host the spoke vnet."
}

variable "azure_backplane_subscription_id" {
  type        = string
  description = "Subscription (bare GUID) where the backplane UAMI + its resource group are created. Typically the hub subscription, so the automation identity lives in a stable, platform-owned place. Deploy once per hub environment (hub-dev, hub-prod) with the respective subscription."

}

variable "backplane_name" {
  type        = string
  default     = "azure-spoke-network"
  description = "Name for the backplane resources (identity, resource group, role definitions). Must match pattern ^[-a-z0-9]+$."
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
  default = {
    owning_workspace_identifier = "flori-land"
    # tags = {
    #   confidentiality = ["Internal"]
    #   environment     = ["dev", "prod"]
    # }
  }

}

variable "hub" {
  type = object({
    git_ref   = optional(string, "main")
    bbd_draft = optional(bool, true)
  })
  const = true
  default = {
    git_ref   = "feature/update-spoke-backplane"
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
  source = "github.com/meshcloud/meshstack-hub//modules/azure/spoke-network/backplane?ref=${var.hub.git_ref}"

  name            = var.backplane_name
  scope           = var.azure_scope
  hub_scope       = var.azure_hub_scope
  location        = var.azure_location
  subscription_id = var.azure_backplane_subscription_id

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
    display_name             = "Azure Spoke Network"
    description              = "Provisions a spoke VNet in the tenant's Azure subscription and peers it into a central network hub for on-premise connectivity and managed internet egress."
    support_url              = "mailto:support@meshcloud.io"
    documentation_url        = "https://hub.meshcloud.io/platforms/azure/definitions/azure-spoke-network"
    notification_subscribers = var.notification_subscribers
    symbol                   = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/main/modules/azure/spoke-network/buildingblock/logo.png"
    target_type              = "TENANT_LEVEL"
    supported_platforms      = [{ name = "AZURE" }]

    readme = chomp(<<-EOT
      This building block provisions a managed **spoke VNet** in your Azure subscription and peers it into a central network hub, giving your workloads secure connectivity to on-premise networks and managed internet egress.

      ## 🎯 When to use it

      Use this building block when your Azure application needs to reach on-premise systems (databases, APIs) or must route egress traffic through the central hub. It creates a dedicated resource group and vnet in your subscription and establishes the bidirectional peering with the hub for you.

      ## 📋 Examples

      1. A team migrating an application to Azure that still depends on an on-premise database requests a spoke network to obtain a routed, hub-connected vnet.
      2. A workload that must send all internet-bound traffic through the central firewall gets connectivity by peering its spoke into the hub.

      ## Shared Responsibilities

      | Responsibility                                   | Platform Team | Application Team |
      | ------------------------------------------------ | :-----------: | :--------------: |
      | Operate the central network hub and its SLA      | ✅            | ❌               |
      | Provision the spoke vnet and hub peering         | ✅            | ❌               |
      | Choose the spoke network name and address space  | ❌            | ✅               |
      | Deploy workloads into the spoke vnet             | ❌            | ✅               |
      | Be mindful of traffic across the hub connection  | ❌            | ✅               |
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
        repository_path                = "modules/azure/spoke-network/buildingblock"
        ref_name                       = var.hub.git_ref
        use_mesh_http_backend_fallback = true

        # Runs after `tofu init`, before the main plan/apply.
        # Works around Azure's eventual consistency without sleeping: it applies
        # the Owner role assignment and the spoke vnet as separate, targeted
        # `tofu apply -target` steps. Each targeted apply is a hard commit
        # boundary, so by the time the main run creates the hub peering the role
        # assignment has propagated and the vnet is committed and visible.
        # https://docs.meshcloud.io/concepts/building-block/#pre-run-script-opentofu
        pre_run_script = chomp(<<-SH
          run_mode="$1"

          # Only pre-provision on APPLY. DESTROY and DETECT are handled by the main run.
          if [ "$run_mode" != "APPLY" ]; then
            echo "Run mode '$run_mode': nothing to pre-apply, skipping."
            exit 0
          fi

          echo "Pre-applying spoke resource group + Owner role assignment (target 1/2)..."
          tofu apply -input=false -auto-approve -target=azurerm_role_assignment.spoke_rg

          echo "Pre-applying spoke vnet (target 2/2)..."
          tofu apply -input=false -auto-approve -target=azurerm_virtual_network.spoke_vnet

          echo "Prerequisites applied; the main run will now create the hub peering."
        SH
        )
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
        display_name    = "Spoke Subscription ID"
        description     = "The Azure subscription where the spoke resource group and vnet are created."
        assignment_type = "PLATFORM_TENANT_ID"
      }
      hub_subscription_id = {
        type            = "STRING"
        display_name    = "Hub Subscription ID"
        description     = "The Azure subscription that hosts the hub vnet."
        assignment_type = "STATIC"
        argument        = jsonencode(var.azure_hub_subscription_id)
      }
      hub_rg = {
        type            = "STRING"
        display_name    = "Hub Resource Group"
        description     = "Name of the resource group that contains the hub vnet."
        assignment_type = "STATIC"
        argument        = jsonencode(var.azure_hub_resource_group_name)
      }
      hub_vnet = {
        type            = "STRING"
        display_name    = "Hub VNet"
        description     = "Name of the hub vnet to peer into."
        assignment_type = "STATIC"
        argument        = jsonencode(var.azure_hub_vnet_name)
      }
      spoke_rg_name = {
        type            = "STRING"
        display_name    = "Spoke Resource Group"
        description     = "Name of the resource group created in the spoke subscription to host the spoke vnet."
        assignment_type = "STATIC"
        argument        = jsonencode(var.azure_spoke_resource_group_name)
      }
      location = {
        type            = "STRING"
        display_name    = "Location"
        description     = "The Azure region where the spoke resource group and vnet are created."
        assignment_type = "STATIC"
        argument        = jsonencode(var.azure_location)
      }
      name = {
        type            = "STRING"
        display_name    = "Spoke Network Name"
        description     = "Name of the spoke network. Used as the basis for the vnet and peering resource names."
        assignment_type = "PROJECT_IDENTIFIER"
        #value_validation_regex         = "^[a-z0-9][-a-z0-9]{1,40}$"
        #validation_regex_error_message = "Only lowercase letters, numbers and dashes are allowed (2–41 characters, must start with a letter or number)."
      }
      address_space = {
        type                           = "STRING"
        display_name                   = "Address Space"
        description                    = "Address space of the spoke virtual network in CIDR notation, e.g. '10.123.0.0/24'."
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$"
        validation_regex_error_message = "Address space must be a valid IPv4 CIDR range, e.g. '10.123.0.0/24'."
      }
    }

    outputs = {
      vnet_id = {
        type            = "STRING"
        display_name    = "Spoke VNet ID"
        description     = "The Azure resource ID of the created spoke virtual network."
        assignment_type = "NONE"
      }
      summary = {
        type            = "STRING"
        display_name    = "Summary"
        description     = "Markdown summary of the created spoke network and its hub peering."
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
      version = ">= 0.21.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.36.0"
    }
  }
}
