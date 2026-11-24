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
  description = "Azure region of the backplane identity and of every virtual machine."
}

variable "backplane_name" {
  type        = string
  default     = "azure-virtual-machine"
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
  source = "github.com/meshcloud/meshstack-hub//modules/azure/azure-virtual-machine/backplane?ref=${var.hub.git_ref}"

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
    display_name             = coalesce(var.bbd_display_name, "Azure Virtual Machine")
    description              = coalesce(var.bbd_description, "Provides a Linux virtual machine in your subscription, with its own virtual network, subnet and network security group, reachable by SSH key.")
    support_url              = "mailto:support@meshcloud.io"
    documentation_url        = "https://hub.meshcloud.io/platforms/azure/definitions/azure-virtual-machine"
    notification_subscribers = var.notification_subscribers
    symbol                   = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/azure/azure-virtual-machine/buildingblock/logo.png"
    target_type              = "TENANT_LEVEL"
    supported_platforms      = var.meshstack.supported_platforms
    run_transparency         = true

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
      This building block provisions an Ubuntu **Linux virtual machine** in your Azure subscription. It creates a resource group, a virtual network with one subnet, a network security group and a network interface for the VM. You log in with the SSH key you provide. The VM has no public IP address.

      ## 🎯 When to use it

      Use this building block when you:
      - Need full control over the operating system and the software on it.
      - Want to run software that does not fit a managed service or a container.
      - Need an isolated machine for development, testing or a build agent.

      ## 💡 Usage examples

      **Example 1: A build agent**
      A team orders a VM, installs its CI agent on it and connects it to its pipeline.

      **Example 2: A legacy application**
      A team moves an application from its own data center to a VM, with the same operating system setup as before.

      ## 🔐 Access

      The VM accepts SSH logins with your key only, as the user `azureuser`. Password login is turned off. It has a private IP address only, so connect through Azure Bastion, a VPN or a jump host.

      The VM has a system-assigned managed identity. Grant this identity roles on other Azure resources, so the VM can use them without stored credentials.

      ## 📊 Shared Responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Provision the VM, its network and its network security group | ✅ | ❌ |
      | Provide the deploy identity and its permissions | ✅ | ❌ |
      | Provide a way to reach the private network | ✅ | ❌ |
      | Keep the SSH private key safe | ❌ | ✅ |
      | Install and patch the operating system and software | ❌ | ✅ |
      | Back up the data on the VM | ❌ | ✅ |
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
        repository_path                = "modules/azure/azure-virtual-machine/buildingblock"
        ref_name                       = var.hub.git_ref
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      vm_name = {
        type                           = "STRING"
        display_name                   = "VM Name"
        description                    = "Name of the virtual machine. The building block also creates the resource group '<name>-rg' and names the network resources after it."
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[a-z][a-z0-9-]{0,58}[a-z0-9]$"
        validation_regex_error_message = "2 to 60 characters: lowercase letters, digits and dashes, starting with a letter and ending with a letter or digit."
        display_order                  = 1
      }
      vm_size = {
        type            = "STRING"
        display_name    = "VM Size"
        description     = "Azure VM size, e.g. 'Standard_B2ts_v2' (2 vCPUs, 1 GB) or 'Standard_B2ls_v2' (2 vCPUs, 4 GB)."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("Standard_B2ts_v2")
        display_order   = 2
      }
      ssh_public_key = {
        type            = "STRING"
        display_name    = "SSH Public Key"
        description     = "The SSH public key for logins as 'azureuser', e.g. the content of ~/.ssh/id_ed25519.pub."
        assignment_type = "USER_INPUT"
        display_order   = 3
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
      location = {
        type            = "STRING"
        display_name    = "Location"
        description     = "The Azure region the virtual machine is created in."
        assignment_type = "STATIC"
        argument        = jsonencode(var.azure_location)
      }
      subscription_id = {
        type            = "STRING"
        display_name    = "Subscription ID"
        description     = "The Azure subscription the virtual machine is created in."
        assignment_type = "PLATFORM_TENANT_ID"
      }
    }

    outputs = {
      vm_id = {
        type            = "STRING"
        display_name    = "VM ID"
        description     = "The Azure resource ID of the virtual machine."
        assignment_type = "NONE"
      }
      vm_name = {
        type            = "STRING"
        display_name    = "VM Name"
        description     = "The name of the virtual machine."
        assignment_type = "NONE"
      }
      vm_private_ip = {
        type            = "STRING"
        display_name    = "Private IP"
        description     = "The private IP address of the virtual machine."
        assignment_type = "NONE"
      }
      resource_group_name = {
        type            = "STRING"
        display_name    = "Resource Group"
        description     = "The resource group containing the virtual machine."
        assignment_type = "NONE"
      }
      azure_portal_url = {
        type            = "STRING"
        display_name    = "Open VM"
        description     = "Azure Portal URL of the virtual machine."
        assignment_type = "RESOURCE_URL"
      }
      summary = {
        type            = "STRING"
        display_name    = "Summary"
        description     = "How to connect to the virtual machine."
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
