variable "stackit_project_id" {
  type        = string
  description = "STACKIT project ID the backplane service account is created in and granted the editor role on. Tenants ordering this block must live in this project."
}

variable "stackit_service_account_name" {
  type        = string
  default     = null
  description = "Name of the backplane service account. Defaults to 'mesh-server'. Override when deploying multiple backplane instances in the same STACKIT project."
}

variable "stackit_region" {
  type        = string
  nullable    = false
  default     = "eu01"
  description = "STACKIT region for the VM and its network resources."
}

variable "image_name_regex" {
  type        = string
  nullable    = false
  default     = "^Ubuntu 22\\.04$"
  description = "Anchored regex matching the STACKIT image the VM boots from, so it skips the ARM64 variant."
}

variable "network_id" {
  type        = string
  nullable    = false
  default     = ""
  description = "Existing STACKIT network to attach the VM to. Empty creates a dedicated one."
}

variable "machine_type" {
  type        = string
  nullable    = false
  default     = "g1.2"
  description = "STACKIT machine flavor for the VM."
}

variable "disk_size_gb" {
  type        = number
  nullable    = false
  default     = 32
  description = "Size of the VM boot volume in GB."
}

variable "ssh_username" {
  type        = string
  nullable    = false
  default     = "ubuntu"
  description = "Default login user of the chosen image, surfaced in the SSH login hint. Match it to image_name_regex."
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

variable "building_block_runner_uuid" {
  type        = string
  default     = null
  description = "Runs this building block on the given meshStack building block runner instead of the shared one meshStack hosts."
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
  `git_ref`: Hub release reference. Set to a tag (e.g. 'v1.2.3') or branch or commit sha of meshcloud/meshstack-hub repo.
  `bbd_draft`: If true, allows changing the building block definition for upgrading dependent building blocks.
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
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/server/backplane?ref=${var.hub.git_ref}"

  project_id           = var.stackit_project_id
  service_account_name = coalesce(var.stackit_service_account_name, "mesh-server")

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
    display_name     = coalesce(var.bbd_display_name, "STACKIT Server")
    symbol           = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/stackit/server/buildingblock/logo.png"
    description      = coalesce(var.bbd_description, "Provisions a STACKIT virtual machine with a generated SSH key and optional personal cloud-init.")
    support_url      = "https://docs.stackit.cloud/stackit/en/virtual-machine-flavors-75137368.html"
    target_type      = "TENANT_LEVEL"
    run_transparency = true

    supported_platforms = [{ name = "STACKIT" }]

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
      This building block provisions a **STACKIT virtual machine** on a dedicated network, reachable
      over SSH with a **key pair generated for you**, so your team gets a ready-to-use Linux server
      without touching the STACKIT console or managing credentials.

      ## 🎯 When to use it

      Use this building block when your team needs:
      - A standalone Linux VM for development, a jump host, or a small always-on service.
      - A VM pre-seeded with your own setup via an optional **personal cloud-init** script.

      ## 💡 Usage examples

      **Example 1: A quick development box**
      Order the VM, read the `ssh_private_key` output, save it to a file, and
      `ssh ubuntu@<public_ip>` — you are in.

      **Example 2: A pre-configured service**
      Paste a `#cloud-config` script into the **Personal cloud-init** field to install packages and
      drop config files on first boot. The generated SSH key still lets you log in to inspect it.

      ## 🔐 Access

      An ED25519 key pair is generated per VM. Only the public key reaches the server (injected by
      STACKIT); the private key is returned as a sensitive building block output. SSH is open on
      TCP 22 — authentication is key-only, and the allowed source range is configurable.

      ## 📊 Shared Responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Provision and network the VM | ✅ | ❌ |
      | Generate and expose the SSH key | ✅ | ❌ |
      | Choose the machine type, name and cloud-init | ❌ | ✅ |
      | Operate, patch and secure the guest OS | ❌ | ✅ |
      | Safeguard the private key | ❌ | ✅ |
      EOT
    ))
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"
    runner_ref = var.building_block_runner_uuid == null ? null : {
      kind = "meshBuildingBlockRunner"
      uuid = var.building_block_runner_uuid
    }

    implementation = {
      terraform = {
        terraform_version              = "1.12.5"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/stackit/server/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      STACKIT_SERVICE_ACCOUNT_EMAIL = {
        display_name    = "STACKIT Service Account Email"
        description     = "Email of the STACKIT service account the provider authenticates as via WIF."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(module.backplane.service_account_email)
      }

      STACKIT_USE_OIDC = {
        display_name    = "STACKIT Use OIDC"
        description     = "Enables OIDC-based WIF for the STACKIT provider."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode("1")
      }

      STACKIT_FEDERATED_TOKEN_FILE = {
        display_name    = "STACKIT Federated Token File"
        description     = "Path to the WIF token file injected by meshStack."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode("/var/run/secrets/workload-identity/azure/token")
      }

      stackit_project_id = {
        display_name    = "STACKIT Project ID"
        description     = "STACKIT project the VM is created in — the platform-native tenant id of the tenant this building block is added to."
        type            = "STRING"
        assignment_type = "PLATFORM_TENANT_ID"
      }

      stackit_region = {
        display_name    = "STACKIT Region"
        description     = "STACKIT region for the VM and its network resources."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.stackit_region)
      }

      availability_zone = {
        display_name    = "Availability Zone"
        description     = "STACKIT availability zone for the VM and its boot volume."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode("${var.stackit_region}-1")
      }

      network_id = {
        display_name    = "Network ID"
        description     = "Existing STACKIT network to attach to. Empty creates a dedicated one."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.network_id)
      }

      image_name_regex = {
        display_name    = "Image Name Regex"
        description     = "Anchored regex matching the STACKIT image the VM boots from."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.image_name_regex)
      }

      disk_size_gb = {
        display_name    = "Disk Size (GB)"
        description     = "Size of the VM boot volume in GB."
        type            = "INTEGER"
        assignment_type = "STATIC"
        argument        = jsonencode(var.disk_size_gb)
      }

      ssh_username = {
        display_name    = "SSH Username"
        description     = "Default login user of the chosen image, surfaced in the SSH login hint."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.ssh_username)
      }

      name = {
        display_name                   = "VM Name"
        description                    = "Name for the VM and its network resources (alphanumeric, dashes, dots, underscores)."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        default_value                  = jsonencode("vm")
        value_validation_regex         = "^[a-zA-Z0-9._-]+$"
        validation_regex_error_message = "Only alphanumeric characters, dots, dashes, and underscores are allowed."
      }

      machine_type = {
        display_name    = "Machine Type"
        description     = "STACKIT machine flavor for the VM, e.g. g1.2 or c1.2."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(var.machine_type)
      }

      ssh_allowed_cidr = {
        display_name           = "SSH Allowed CIDR"
        description            = "CIDR range allowed to reach the VM on TCP 22. Authentication is key-only; narrow this in production."
        type                   = "STRING"
        assignment_type        = "USER_INPUT"
        default_value          = jsonencode("0.0.0.0/0")
        updateable_by_consumer = true
      }

      cloud_init = {
        display_name           = "Personal cloud-init"
        description            = "Optional #cloud-config applied to the VM on first boot. Leave empty for none."
        type                   = "CODE"
        assignment_type        = "USER_INPUT"
        default_value          = jsonencode("")
        updateable_by_consumer = true
      }
    }

    outputs = {
      public_ip = {
        display_name    = "Public IP"
        type            = "STRING"
        assignment_type = "NONE"
      }

      ssh_username = {
        display_name    = "SSH Username"
        type            = "STRING"
        assignment_type = "NONE"
      }

      ssh_command = {
        display_name    = "SSH Command"
        type            = "STRING"
        assignment_type = "NONE"
      }

      ssh_private_key = {
        display_name    = "SSH Private Key"
        type            = "STRING"
        assignment_type = "NONE"
      }

      server_id = {
        display_name    = "Server ID"
        type            = "STRING"
        assignment_type = "NONE"
      }

      summary = {
        display_name    = "Summary"
        type            = "STRING"
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
      version = ">= 0.26.2"
    }
  }
}
