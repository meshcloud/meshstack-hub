variable "azure_tenant_id" {
  type        = string
  description = "Azure Entra tenant ID used for the building block's ARM authentication (ARM_TENANT_ID)."
}

variable "azure_connectivity_subscription_id" {
  type        = string
  description = "Bare GUID of the connectivity subscription where the hub vnet, firewall and the backplane UAMI are created."
  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.azure_connectivity_subscription_id))
    error_message = "Must be a bare subscription GUID, not a '/subscriptions/<guid>' path."
  }
}

variable "azure_scope" {
  type        = string
  description = "RBAC scope where the hub deploy role is granted — a full resource path: a management group ('/providers/Microsoft.Management/managementGroups/<id>') or a subscription ('/subscriptions/<guid>'). Typically the platform Connectivity scope."
  validation {
    condition     = can(regex("^/subscriptions/[0-9a-fA-F-]{36}$|^/providers/Microsoft\\.Management/managementGroups/.+$", var.azure_scope))
    error_message = "Must be a full resource path: '/subscriptions/<guid>' or '/providers/Microsoft.Management/managementGroups/<id>', not a bare GUID."
  }
}

variable "azure_location" {
  type        = string
  default     = "germanywestcentral"
  description = "Default Azure region where the hub resource group, vnet and firewall are created."
}

variable "backplane_name" {
  type        = string
  default     = "azure-hub-network"
  description = "Name for the backplane resources (identity, resource group, role definition). Must match pattern ^[-a-z0-9]+$."
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

data "meshstack_integrations" "integrations" {}

module "backplane" {
  source = "./backplane"

  name            = var.backplane_name
  scope           = var.azure_scope
  location        = var.azure_location
  subscription_id = var.azure_connectivity_subscription_id

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
    display_name             = "Azure Hub Network"
    description              = "Provisions the central hub vnet (resource group, hub vnet, GatewaySubnet and an optional Azure Firewall) that spoke networks peer into."
    support_url              = "mailto:support@meshcloud.io"
    documentation_url        = "https://hub.meshcloud.io/platforms/azure/definitions/azure-hub-network"
    notification_subscribers = var.notification_subscribers
    symbol                   = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/main/modules/azure/hub-network/buildingblock/logo.png"
    target_type              = "WORKSPACE_LEVEL"

    readme = chomp(<<-EOT
      This building block provisions the **central hub** of a hub-and-spoke Azure network topology: a
      resource group, the hub virtual network, a `GatewaySubnet`, and an optional Azure Firewall with
      a static public IP and an egress route table. Spoke networks ordered via the **Azure Spoke
      Network** building block peer into this hub.

      ## 🎯 When to use it

      Order this once per connectivity environment to establish the hub that all spoke networks
      connect to. This is a platform-team building block.

      ## Shared Responsibilities

      | Responsibility | Platform Team | Application Team |
      | -------------- | :-----------: | :--------------: |
      | Provision and operate the hub vnet and firewall | ✅ | ❌ |
      | Choose the hub address space and firewall SKU | ✅ | ❌ |
      | Order spoke networks and use the connectivity | ❌ | ✅ |
    EOT
    )
  }

  version_spec = {
    draft = var.hub.bbd_draft

    deletion_mode = "DELETE"

    implementation = {
      terraform = {
        terraform_version              = "1.12.5"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/azure/hub-network/buildingblock"
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
      ARM_SUBSCRIPTION_ID = {
        type            = "STRING"
        display_name    = "ARM Subscription ID"
        description     = "The connectivity subscription where the hub is created."
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(var.azure_connectivity_subscription_id)
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
      hub_resource_group_name = {
        type            = "STRING"
        display_name    = "Hub Resource Group"
        description     = "Name of the resource group created in the connectivity subscription to host the hub vnet and firewall."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("hub-network")
      }
      hub_vnet_name = {
        type            = "STRING"
        display_name    = "Hub VNet Name"
        description     = "Name of the central hub virtual network."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("hub-vnet")
      }
      address_space = {
        type                           = "STRING"
        display_name                   = "Address Space"
        description                    = "Address space of the hub virtual network in CIDR notation, e.g. '10.0.0.0/22'. Needs room for the derived AzureFirewallSubnet and GatewaySubnet."
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$"
        validation_regex_error_message = "Address space must be a valid IPv4 CIDR range, e.g. '10.0.0.0/22'."
      }
      location = {
        type            = "STRING"
        display_name    = "Location"
        description     = "The Azure region where the hub is created."
        assignment_type = "STATIC"
        argument        = jsonencode(var.azure_location)
      }
      create_gateway_subnet = {
        type            = "BOOLEAN"
        display_name    = "Create Gateway Subnet"
        description     = "Create a GatewaySubnet for a future VPN/ExpressRoute gateway."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(true)
      }
      deploy_firewall = {
        type            = "BOOLEAN"
        display_name    = "Deploy Firewall"
        description     = "Deploy an Azure Firewall with a public IP and an egress route table pointing at it."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(false)
      }
      firewall_sku_tier = {
        type            = "STRING"
        display_name    = "Firewall SKU Tier"
        description     = "Azure Firewall SKU tier: Standard or Premium."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("Standard")
      }
    }

    outputs = {
      vnet_id = {
        type            = "STRING"
        display_name    = "Hub VNet ID"
        description     = "The Azure resource ID of the hub virtual network."
        assignment_type = "NONE"
      }
      vnet_name = {
        type            = "STRING"
        display_name    = "Hub VNet Name"
        description     = "The name of the hub virtual network. Spoke networks peer into this vnet."
        assignment_type = "NONE"
      }
      resource_group_name = {
        type            = "STRING"
        display_name    = "Hub Resource Group"
        description     = "The name of the hub resource group."
        assignment_type = "NONE"
      }
      firewall_private_ip = {
        type            = "STRING"
        display_name    = "Firewall Private IP"
        description     = "Private IP of the Azure Firewall, if deployed."
        assignment_type = "NONE"
      }
      summary = {
        type            = "STRING"
        display_name    = "Summary"
        description     = "Markdown summary of the created hub network."
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
      version = ">= 4.36"
    }
  }
}
