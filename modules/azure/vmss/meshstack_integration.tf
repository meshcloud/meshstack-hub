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
  description = "Azure region of the backplane identity and of every scale set. The virtual network the scale set joins must be in this region."
}

variable "backplane_name" {
  type        = string
  default     = "azure-vmss"
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

module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/azure/vmss/backplane?ref=${var.hub.git_ref}"

  name     = var.backplane_name
  scope    = var.azure_scope
  location = var.azure_location

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
    display_name             = coalesce(var.bbd_display_name, "Azure Virtual Machine Scale Set")
    description              = coalesce(var.bbd_description, "Creates a Linux virtual machine scale set in an existing subnet of your subscription, with an optional load balancer and CPU-based autoscaling.")
    support_url              = "mailto:support@meshcloud.io"
    documentation_url        = "https://hub.meshcloud.io/platforms/azure/definitions/azure-vmss"
    notification_subscribers = var.notification_subscribers
    symbol                   = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/azure/vmss/buildingblock/logo.png"
    target_type              = "TENANT_LEVEL"
    supported_platforms      = var.meshstack.supported_platforms
    run_transparency         = true

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
      This building block creates a **Linux virtual machine scale set** in your Azure subscription: a group of identical VMs that you can scale by hand or by CPU load. It goes into a subnet of a virtual network that already exists, for example one created by the spoke network building block. It can put an internal or public load balancer in front of the VMs.

      ## 🎯 When to use it

      Use this building block when you:
      - Run a stateless application that needs several identical VMs.
      - Want the number of VMs to follow the CPU load.
      - Already have a virtual network and subnet in your subscription for the VMs.

      ## 💡 Usage examples

      **Example 1: A web application behind a load balancer**
      A team runs two VMs behind an internal load balancer on port 80 and installs nginx with a cloud-init script.

      **Example 2: A batch worker pool that scales with load**
      A team enables autoscaling between 1 and 5 VMs, so more VMs start when the average CPU load is high.

      ## 🌐 Network

      The building block attaches its own network security group to the subnet you name. A network security group that the subnet already has is replaced. So use a subnet only for this scale set.

      ## 📊 Shared Responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Provide the deployment identity and its permissions | ✅ | ❌ |
      | Create the scale set, load balancer and network security group | ✅ | ❌ |
      | Provide the virtual network and subnet | ❌ | ✅ |
      | Choose VM size, instance count and autoscaling limits | ❌ | ✅ |
      | Install, patch and run the application on the VMs | ❌ | ✅ |
      | Keep the SSH key safe | ❌ | ✅ |
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
        repository_path                = "modules/azure/vmss/buildingblock"
        ref_name                       = var.hub.git_ref
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      vmss_name = {
        type                           = "STRING"
        display_name                   = "Scale Set Name"
        description                    = "Name of the scale set. It also prefixes the names of the load balancer and the network security group."
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[a-z0-9-]{1,64}$"
        validation_regex_error_message = "1 to 64 characters: lowercase letters, digits and dashes."
        display_order                  = 1
      }
      resource_group_name = {
        type                           = "STRING"
        display_name                   = "Resource Group Name"
        description                    = "Resource group the building block creates for the scale set. It is deleted with the building block."
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[-\\w\\._\\(\\)]{1,90}$"
        validation_regex_error_message = "1 to 90 characters: letters, digits, underscores, dashes, periods and parentheses."
        display_order                  = 2
      }
      vnet_resource_group_name = {
        type            = "STRING"
        display_name    = "VNet Resource Group"
        description     = "Resource group of the existing virtual network."
        assignment_type = "USER_INPUT"
        display_order   = 3
      }
      vnet_name = {
        type            = "STRING"
        display_name    = "VNet Name"
        description     = "Name of the existing virtual network. It must be in region ${var.azure_location}."
        assignment_type = "USER_INPUT"
        display_order   = 4
      }
      subnet_name = {
        type            = "STRING"
        display_name    = "Subnet Name"
        description     = "Name of the existing subnet the VMs join. The building block attaches its network security group to this subnet."
        assignment_type = "USER_INPUT"
        display_order   = 5
      }
      ssh_public_key = {
        type            = "STRING"
        display_name    = "SSH Public Key"
        description     = "SSH public key for the admin user 'azureuser', e.g. 'ssh-rsa AAAA...'."
        assignment_type = "USER_INPUT"
        display_order   = 6
      }
      sku = {
        type            = "STRING"
        display_name    = "VM Size"
        description     = "Azure VM size of every instance, e.g. 'Standard_B2ls_v2' or 'Standard_D2s_v5'."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("Standard_B2ls_v2")
        display_order   = 7
      }
      instances = {
        type            = "INTEGER"
        display_name    = "Instances"
        description     = "Number of VMs. With autoscaling, the number of VMs at the start."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(2)
        display_order   = 8
      }
      enable_autoscaling = {
        type            = "BOOLEAN"
        display_name    = "Autoscaling"
        description     = "Add or remove one VM when the average CPU load is above 75% or below 25%."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(false)
        display_order   = 9
      }
      min_instances = {
        type            = "INTEGER"
        display_name    = "Minimum Instances"
        description     = "Autoscaling never goes below this number of VMs."
        assignment_type = "USER_INPUT"
        condition       = "input.enable_autoscaling == true"
        default_value   = jsonencode(1)
        display_order   = 10
      }
      max_instances = {
        type            = "INTEGER"
        display_name    = "Maximum Instances"
        description     = "Autoscaling never goes above this number of VMs."
        assignment_type = "USER_INPUT"
        condition       = "input.enable_autoscaling == true"
        default_value   = jsonencode(5)
        display_order   = 11
      }
      enable_load_balancer = {
        type            = "BOOLEAN"
        display_name    = "Load Balancer"
        description     = "Put a Standard load balancer in front of the VMs. It forwards port 80 to port 80 of the VMs."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(true)
        display_order   = 12
      }
      enable_public_ip = {
        type            = "BOOLEAN"
        display_name    = "Public IP"
        description     = "Give the load balancer a public IP. Without it, the load balancer has a private IP in the subnet."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(false)
        display_order   = 13
      }
      enable_ssh_access = {
        type            = "BOOLEAN"
        display_name    = "SSH Access"
        description     = "Allow inbound SSH (port 22) from anywhere in the network security group."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(false)
        display_order   = 14
      }
      custom_data = {
        type            = "CODE"
        display_name    = "Cloud-Init Script"
        description     = "Script or cloud-init configuration that every VM runs at its first boot."
        assignment_type = "USER_INPUT"
        is_optional     = true
        display_order   = 15
      }
      subscription_id = {
        type            = "STRING"
        display_name    = "Subscription ID"
        description     = "The Azure subscription the scale set is created in."
        assignment_type = "PLATFORM_TENANT_ID"
      }
      location = {
        type            = "STRING"
        display_name    = "Location"
        description     = "The Azure region the scale set is created in."
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
    }

    outputs = {
      vmss_id = {
        type            = "STRING"
        display_name    = "Scale Set ID"
        description     = "The Azure resource ID of the scale set."
        assignment_type = "NONE"
      }
      vmss_name = {
        type            = "STRING"
        display_name    = "Scale Set Name"
        description     = "The name of the scale set."
        assignment_type = "NONE"
      }
      resource_group_name = {
        type            = "STRING"
        display_name    = "Resource Group"
        description     = "The resource group containing the scale set."
        assignment_type = "NONE"
      }
      vmss_identity_principal_id = {
        type            = "STRING"
        display_name    = "Managed Identity Principal ID"
        description     = "Principal ID of the scale set's system-assigned managed identity. Grant it roles to let the VMs access other Azure resources."
        assignment_type = "NONE"
      }
      summary = {
        type            = "STRING"
        display_name    = "Summary"
        description     = "A markdown summary of the scale set and how to manage it."
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
