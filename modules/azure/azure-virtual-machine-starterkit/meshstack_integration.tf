variable "full_platform_identifier" {
  type        = string
  description = "Full identifier of the Azure platform (example: `azure.westeurope`)."
}

variable "landing_zone_identifier" {
  type        = string
  description = "Azure landing zone identifier for the created tenant."
}

variable "azure_vm_definition_version_uuid" {
  type        = string
  description = "Version UUID of the Azure Virtual Machine building block definition that this starter kit composes."
}

variable "project_tags" {
  type        = map(list(string))
  default     = {}
  description = "Tags applied to the created meshProject."
}

variable "notification_subscribers" {
  type    = list(string)
  default = []
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string

    tags = optional(map(list(string)), {})
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

locals {
  name_regex = "^[a-zA-Z0-9-]{0,24}$" # keep aligned with the other starter kits (project/name length limits)
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    description              = "The Azure Virtual Machine Starterkit provisions a dedicated meshProject and Azure tenant, then composes an Azure Virtual Machine building block to deliver a ready-to-use VM."
    display_name             = "Azure Virtual Machine Starterkit"
    notification_subscribers = var.notification_subscribers
    symbol                   = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/azure/azure-virtual-machine-starterkit/buildingblock/logo.png"

    readme = chomp(<<-EOT
    The **Azure Virtual Machine Starterkit** gives application teams a pre-configured Azure environment with a single virtual machine, following best practices. It creates a dedicated meshProject and Azure tenant and composes the Azure Virtual Machine building block to provision the VM.

    ## 🎯 When to use it

    This building block is ideal for teams that:

    -   Need a quick, governed Azure VM without assembling project, tenant and VM wiring by hand.
    -   Want a Linux VM in a landing-zone-compliant tenant.

    ## Resources Created

    - **Azure Project**: A dedicated meshProject for your virtual machine resources.
    - **Azure Tenant**: An Azure subscription tenant on your chosen landing zone.
    - **Virtual Machine**: A Linux VM (composed via the Azure Virtual Machine building block).

    ## Shared Responsibilities

    | Responsibility                            | Platform Team | Application Team |
    | ----------------------------------------- | ------------- | ---------------- |
    | Provide the Azure platform + landing zone | ✅            | ❌               |
    | Provision project, tenant and VM          | ✅            | ❌               |
    | Manage workloads on the VM                | ❌            | ✅               |
    | Rotate SSH keys / credentials             | ❌            | ✅               |

    ---
    EOT
    )
    run_transparency = true
  }

  version_spec = {
    draft = var.hub.bbd_draft
    implementation = {
      terraform = {
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        terraform_version              = "1.11.5"
        async                          = false
        ref_name                       = var.hub.git_ref
        repository_path                = "modules/azure/azure-virtual-machine-starterkit/buildingblock"
        use_mesh_http_backend_fallback = true
      }
    }
    inputs = {
      "creator" = {
        assignment_type = "AUTHOR"
        description     = "Information about the creator of the resources who will be assigned Project Admin role."
        display_name    = "Creator"
        type            = "CODE"
      }
      "workspace_identifier" = {
        assignment_type = "WORKSPACE_IDENTIFIER"
        display_name    = "Workspace Identifier"
        type            = "STRING"
      }
      "full_platform_identifier" = {
        argument        = jsonencode(var.full_platform_identifier)
        assignment_type = "STATIC"
        display_name    = "Full Platform Identifier"
        type            = "STRING"
      }
      "landing_zone_identifier" = {
        argument        = jsonencode(var.landing_zone_identifier)
        assignment_type = "STATIC"
        display_name    = "Landing Zone Identifier"
        type            = "STRING"
      }
      "azure_vm_definition_version_uuid" = {
        argument        = jsonencode(var.azure_vm_definition_version_uuid)
        assignment_type = "STATIC"
        display_name    = "Azure VM Definition Version UUID"
        type            = "STRING"
      }
      "project_tags_yaml" = {
        # buildingblock expects a YAML string it yamldecodes; jsonencode wraps the YAML string as the STATIC argument.
        argument        = jsonencode(yamlencode(var.project_tags))
        assignment_type = "STATIC"
        description     = "Tags for the created project (YAML)."
        display_name    = "Project Tags"
        type            = "STRING"
      }
      "name" = {
        assignment_type                = "USER_INPUT"
        description                    = "Used for the created project and VM."
        display_name                   = "Name"
        type                           = "STRING"
        value_validation_regex         = local.name_regex
        validation_regex_error_message = "No underscore/dots/spaces are allowed. A maximum length of 25 characters is allowed."
      }
      "vm_location" = {
        assignment_type = "USER_INPUT"
        description     = "Azure region where the VM is deployed."
        display_name    = "VM Location"
        type            = "STRING"
        default_value   = jsonencode("westeurope")
      }
      "vm_size" = {
        assignment_type = "USER_INPUT"
        description     = "Size of the virtual machine."
        display_name    = "VM Size"
        type            = "STRING"
        default_value   = jsonencode("Standard_B1s")
      }
      "vm_admin_username" = {
        assignment_type = "USER_INPUT"
        description     = "Admin username for the VM."
        display_name    = "VM Admin Username"
        type            = "STRING"
        default_value   = jsonencode("azureuser")
      }
      "vm_ssh_public_key" = {
        assignment_type = "USER_INPUT"
        description     = "SSH public key used to authenticate as the VM's admin user."
        display_name    = "VM SSH Public Key"
        type            = "STRING"
      }
      "vm_enable_public_ip" = {
        assignment_type = "USER_INPUT"
        description     = "Whether to assign a public IP to the VM."
        display_name    = "Enable Public IP"
        type            = "BOOLEAN"
        default_value   = jsonencode(false)
      }
    }
    outputs = {
      "summary" = {
        assignment_type = "SUMMARY"
        display_name    = "Summary"
        type            = "STRING"
      }
    }
    permissions = [
      "BUILDINGBLOCK_DELETE",
      "BUILDINGBLOCK_LIST",
      "BUILDINGBLOCK_SAVE",
      "PROJECTPRINCIPALROLE_DELETE",
      "PROJECTPRINCIPALROLE_LIST",
      "PROJECTPRINCIPALROLE_SAVE",
      "PROJECT_DELETE",
      "PROJECT_LIST",
      "PROJECT_SAVE",
      "TENANT_DELETE",
      "TENANT_LIST",
      "TENANT_SAVE",
    ]
  }
}

terraform {
  required_version = ">= 1.12.0"

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.21.0"
    }
  }
}
