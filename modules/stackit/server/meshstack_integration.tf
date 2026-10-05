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
  description = "Regex matching the STACKIT image name the VM boots from."
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
  default     = "g1a.1d"
  description = "STACKIT machine flavor for the VM."
}

variable "disk_size_gb" {
  type        = number
  nullable    = false
  default     = 20
  description = "Size of the VM boot volume in GB."
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
  `git_ref`: Hub release reference. Set to a tag (e.g. 'v1.2.3') or branch or commit sha of meshcloud/meshstack-hub repo.<br>
  `bbd_draft`: If true, allows changing the building block definition for upgrading dependent building blocks.
  EOT
}

output "building_block_definition" {
  description = "BBD is consumed in building block compositions."
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = meshstack_building_block_definition.this.version_latest
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name = coalesce(var.bbd_display_name, "STACKIT Virtual Machine")
    symbol       = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/stackit/server/buildingblock/logo.png"
    description = coalesce(var.bbd_description, chomp(<<-EOT
      Deploys a STACKIT VM with an optional public IP, a generated or supplied SSH key, and an optional personal cloud-init.
    EOT
    ))
    support_url         = "https://portal.stackit.cloud"
    target_type         = "TENANT_LEVEL"
    run_transparency    = true
    supported_platforms = [{ name = "STACKIT" }]

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
    The **STACKIT Virtual Machine** building block deploys a single VM on its own network in your
    STACKIT project, ready to log in to the moment it comes up.

    ## 📦 What it provisions

    - A **STACKIT VM** (server, network, security group, network interface) booting a STACKIT image
      resolved by name.
    - An **SSH key** authorized on the VM. Leave the public key empty and the block generates an
      ed25519 key pair and returns the **private key as an output**; or supply your own public key.
    - An **optional public IP**. When enabled, inbound SSH (port 22) is opened to the CIDR you
      choose, so you can connect directly. When disabled, the VM stays private.
    - An **optional personal cloud-init** run on first boot, for any extra setup you need.

    ## 🔐 Logging in

    When a public IP is attached, read the `public_ip` and (if generated) `ssh_private_key` outputs,
    then connect as the image's default user:

    ```bash
    ssh ubuntu@<public_ip>
    ```

    > ⚠️ meshStack has no sensitive outputs, so a generated private key is shown in the clear. Treat
    > it as a first-login convenience — rotate or remove the key once the VM is configured, or supply
    > your own public key instead.

    ## 📊 Shared Responsibility

    | Responsibility | Platform Team | Application Team |
    |---|:---:|:---:|
    | Provide the backplane identity used to create the VM | ✅ | ❌ |
    | Choose region, flavor, image and disk defaults | ✅ | ❌ |
    | Decide whether the VM gets a public IP and from where SSH is reachable | ❌ | ✅ |
    | Manage SSH keys and anything installed via cloud-init | ❌ | ✅ |
    | Patch and operate the guest OS | ❌ | ✅ |
    EOT
    ))
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"

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
        display_name           = "STACKIT Service Account Email"
        description            = "Email of the STACKIT service account the provider authenticates as via WIF."
        type                   = "STRING"
        assignment_type        = "USER_INPUT"
        is_environment         = true
        updateable_by_consumer = true
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
        description     = "Regex matching the STACKIT image name the VM boots from."
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

      name = {
        display_name                   = "VM Name"
        description                    = "Name for the VM (alphanumeric, dashes, dots, underscores)."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        default_value                  = jsonencode("vm")
        value_validation_regex         = "^[a-zA-Z0-9._-]+$"
        validation_regex_error_message = "Only alphanumeric characters, dots, dashes, and underscores are allowed."
      }

      machine_type = {
        display_name    = "Machine Type"
        description     = "STACKIT machine flavor for the VM, e.g. g1a.1d or c1a.2d."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(var.machine_type)
      }

      enable_public_ip = {
        display_name    = "Attach Public IP"
        description     = "Attaches a public IP and opens inbound SSH, so the VM is reachable directly after creation."
        type            = "BOOLEAN"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(true)
      }

      ssh_allowed_cidr = {
        display_name           = "SSH Allowed CIDR"
        description            = "CIDR allowed to reach SSH (port 22) when a public IP is attached. Narrow this to your own network for anything long-lived."
        type                   = "STRING"
        assignment_type        = "USER_INPUT"
        default_value          = jsonencode("0.0.0.0/0")
        updateable_by_consumer = true
      }

      ssh_public_key = {
        display_name    = "SSH Public Key"
        description     = "OpenSSH public key to authorize on the VM. Leave empty to have one generated and returned as an output."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("")
      }

      cloud_init = {
        display_name    = "Cloud-init"
        description     = "Optional cloud-init user data run on first boot. Leave empty to boot the image unmodified."
        type            = "CODE"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("")
      }
    }

    outputs = {
      server_id = {
        display_name    = "Server ID"
        type            = "STRING"
        assignment_type = "NONE"
      }

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

      ssh_private_key = {
        display_name    = "SSH Private Key"
        type            = "CODE"
        assignment_type = "NONE"
      }

      ssh_key_pair_name = {
        display_name    = "SSH Key Pair Name"
        type            = "STRING"
        assignment_type = "NONE"
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
  }
}
