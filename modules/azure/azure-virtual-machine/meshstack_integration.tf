variable "azure_tenant_id" {
  type        = string
  description = "Azure Entra tenant ID used for provider authentication."
}

variable "azure_scope" {
  type        = string
  description = "Azure management group or subscription ID used for the backplane role scope (typically the parent of all landing zones)."
}

variable "backplane_name" {
  type        = string
  default     = "azure-virtual-machine"
  description = "Name for the backplane resources (service principal, role definition). Must match pattern ^[-a-z0-9]+$."
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
  source = "github.com/meshcloud/meshstack-hub//modules/azure/azure-virtual-machine/backplane?ref=${var.hub.git_ref}"

  name  = var.backplane_name
  scope = var.azure_scope

  create_service_principal_name = var.backplane_name

  workload_identity_federation = {
    issuer  = data.meshstack_integrations.integrations.workload_identity_federation.replicator.issuer
    subject = "${trimsuffix(data.meshstack_integrations.integrations.workload_identity_federation.replicator.subject, ":replicator")}:workspace.${var.meshstack.owning_workspace_identifier}.buildingblockdefinition.${meshstack_building_block_definition.this.metadata.uuid}"
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name             = "Azure Virtual Machine"
    description              = "Provisions a single Linux Azure Virtual Machine with its own virtual network, subnet, network security group and optional public IP and data disk, in the target tenant's subscription."
    support_url              = "mailto:support@meshcloud.io"
    documentation_url        = "https://hub.meshcloud.io/platforms/azure/definitions/azure-virtual-machine"
    notification_subscribers = var.notification_subscribers
    symbol                   = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/azure/azure-virtual-machine/buildingblock/logo.png"
    target_type              = "TENANT_LEVEL"
    supported_platforms      = [{ name = "AZURE" }]

    readme = chomp(<<-EOT
    Provisions a single **Linux Azure Virtual Machine** with a dedicated virtual network, subnet, network security group, system-assigned managed identity and an optional public IP and data disk. The VM is deployed into the target tenant's Azure subscription.

    ## 🎯 When to use it

    Use this building block when your team needs a dedicated Linux compute instance with full OS control, for example to:

    -   Run a Linux workload that isn't a good fit for managed/containerized services.
    -   Host an application server, database, build agent or lift-and-shift migration.
    -   Get an isolated dev/test environment with predictable performance.

    ## Resources Created

    - **Virtual Machine**: A Linux VM with a system-assigned managed identity.
    - **Networking**: A virtual network, subnet, network interface and network security group (plus an optional public IP).
    - **Storage**: An OS disk and an optional data disk.

    ## Shared Responsibilities

    | Responsibility                                  | Platform Team | Application Team |
    | ----------------------------------------------- | :-----------: | :--------------: |
    | Provision and configure VM infrastructure       | ✅            | ❌               |
    | Manage virtual networks and subnets             | ✅            | ❌               |
    | Provide secure access methods (Bastion, VPN)    | ✅            | ❌               |
    | Install and configure applications              | ❌            | ✅               |
    | Manage OS updates and patches                   | ❌            | ✅               |
    | Manage user access and SSH keys / credentials   | ❌            | ✅               |
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
        repository_path                = "modules/azure/azure-virtual-machine/buildingblock"
        ref_name                       = var.hub.git_ref
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      ARM_CLIENT_ID = {
        type            = "STRING"
        display_name    = "ARM Client ID"
        description     = "Client ID of the service principal used to authenticate with Azure."
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(module.backplane.created_service_principal.client_id)
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
        description     = "The Azure subscription ID (target tenant) where the virtual machine will be deployed."
        assignment_type = "PLATFORM_TENANT_ID"
      }
      vm_name = {
        type            = "STRING"
        display_name    = "VM Name"
        description     = "The name of the virtual machine (also used to name the resource group and networking resources)."
        assignment_type = "USER_INPUT"
      }
      location = {
        type            = "STRING"
        display_name    = "Location"
        description     = "The Azure region where the VM will be deployed."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("westeurope")
      }
      vm_size = {
        type            = "STRING"
        display_name    = "VM Size"
        description     = "The size of the virtual machine."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("Standard_B1s")
      }
      admin_username = {
        type            = "STRING"
        display_name    = "Admin Username"
        description     = "The admin username for the VM."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("azureuser")
      }
      ssh_public_key = {
        type            = "STRING"
        display_name    = "SSH Public Key"
        description     = "SSH public key used to authenticate as the VM's admin user."
        assignment_type = "USER_INPUT"
      }
      enable_public_ip = {
        type            = "BOOLEAN"
        display_name    = "Enable Public IP"
        description     = "Whether to create and assign a public IP address to the VM."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(false)
      }
      os_disk_size_gb = {
        type            = "INTEGER"
        display_name    = "OS Disk Size (GB)"
        description     = "The size of the OS disk in GB."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(30)
      }
      data_disk_size_gb = {
        type            = "INTEGER"
        display_name    = "Data Disk Size (GB)"
        description     = "The size of the data disk in GB. Set to 0 to skip data disk creation."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(0)
      }
      enable_spot_instance = {
        type            = "BOOLEAN"
        display_name    = "Enable Spot Instance"
        description     = "Run the VM as a cost-optimized spot instance (can be evicted when Azure needs capacity). Suitable for dev/test and non-critical workloads."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(false)
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
        description     = "The private IP address of the VM."
        assignment_type = "NONE"
      }
      vm_public_ip = {
        type            = "STRING"
        display_name    = "Public IP"
        description     = "The public IP address of the VM (if enabled)."
        assignment_type = "NONE"
      }
      resource_group_name = {
        type            = "STRING"
        display_name    = "Resource Group"
        description     = "The name of the resource group containing the VM."
        assignment_type = "NONE"
      }
      azure_portal_url = {
        type            = "STRING"
        display_name    = "Azure Portal URL"
        description     = "Direct link to the VM in the Azure Portal."
        assignment_type = "NONE"
      }
      summary = {
        type            = "STRING"
        display_name    = "Summary"
        description     = "Markdown summary of the created VM with connection instructions."
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
      version = ">= 4.50"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 3.6"
    }
  }
}
