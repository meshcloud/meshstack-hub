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
  description = "Regex matching the STACKIT image name the runner boots from."
}

variable "network_id" {
  type        = string
  nullable    = false
  default     = ""
  description = "Existing STACKIT network to attach the runner to. Empty creates a dedicated one."
}

variable "machine_type" {
  type        = string
  nullable    = false
  default     = "c1.2"
  description = "STACKIT machine flavor for the runner VM."
}

variable "runner_labels" {
  type        = list(string)
  nullable    = false
  default     = ["stackit-ubuntu-22:host"]
  description = "Runner labels, each `<label>:host` or `<label>:docker://<image>`, targeted by workflows via runs-on."
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
    display_name = coalesce(var.bbd_display_name, "STACKIT Git Runner")
    symbol       = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/stackit/git-runner/buildingblock/logo.png"
    description = coalesce(var.bbd_description, chomp(<<-EOT
      Deploys a STACKIT VM running a self-hosted STACKIT Git Actions runner at organization scope.
    EOT
    ))
    support_url         = "https://docs.stackit.cloud/stackit/en/stackit-git-360816204.html"
    target_type         = "TENANT_LEVEL"
    run_transparency    = true
    supported_platforms = [{ name = "STACKIT" }]

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
    The **STACKIT Git Runner** building block deploys a self-hosted CI runner for STACKIT Git on a
    STACKIT VM the platform controls, so pipelines in an organization's repositories run on a
    machine flavor, image and labels of its choosing.

    ## 📦 What it provisions

    - A **STACKIT VM** (server, network, security group, network interface) provisioned via
      cloud-init on first boot. The VM has **no inbound access** — it reaches the Git instance
      through the network router's outbound NAT.
    - A **STACKIT Git Actions runner** installed and run as a systemd daemon, registered at
      **organization scope** — one runner serves every repository in the organization.

    The registration token is minted at run time via the STACKIT Git API using an org-admin PAT, and
    handed to the VM through cloud-init. The PAT itself never reaches the VM. **Prerequisite:**
    Actions must be enabled on the STACKIT Git instance.

    ## 🏷️ Using it in workflows

    Target the runner from a workflow with its labels, e.g. `runs-on: stackit-ubuntu-22` — the same
    label STACKIT's shared managed runners carry, so existing workflows need no change.

    ## 📊 Shared Responsibility

    | Responsibility | Platform Team | Application Team |
    |---|:---:|:---:|
    | Provision and operate the runner VM | ✅ | ❌ |
    | Register the runner with STACKIT Git | ✅ | ❌ |
    | Enable Actions on the Git instance | ✅ | ❌ |
    | Author CI workflows that use the runner | ❌ | ✅ |
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
        repository_path                = "modules/stackit/git-runner/buildingblock"
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
        description     = "STACKIT project the runner VM is created in — the platform-native tenant id of the tenant this building block is added to."
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
        description     = "Regex matching the STACKIT image name the runner VM boots from."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.image_name_regex)
      }

      runner_labels = {
        display_name    = "Runner Labels"
        description     = "STACKIT Git Actions runner labels referenced by workflows via runs-on."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.runner_labels))
      }

      runner_version = {
        display_name    = "Runner Version"
        description     = "Version of the runner agent installed on the VM."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode("6.3.1")
      }

      node_version = {
        display_name    = "Node.js Version"
        description     = "Node.js version installed on the VM for JavaScript actions."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode("20.18.1")
      }

      disk_size_gb = {
        display_name    = "Disk Size (GB)"
        description     = "Size of the runner VM boot volume in GB."
        type            = "INTEGER"
        assignment_type = "STATIC"
        argument        = jsonencode(50)
      }

      git_base_url = {
        display_name           = "STACKIT Git Base URL"
        description            = "Base URL of the STACKIT Git instance, e.g. https://<name>.git.onstackit.cloud."
        type                   = "STRING"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
      }

      git_organization = {
        display_name           = "STACKIT Git Organization"
        description            = "Organization the runner is registered for."
        type                   = "STRING"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
      }

      forgejo_api_token = {
        display_name    = "STACKIT Git PAT"
        description     = "Org-admin PAT used to mint the runner registration token."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        sensitive       = {}

        # A rotated token has to reach the block that was already ordered with the old one.
        updateable_by_consumer = true
      }

      name = {
        display_name                   = "Runner Name / Identifier"
        description                    = "Name for the runner and its VM (alphanumeric, dashes, dots, underscores)."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        default_value                  = jsonencode("git-runner")
        value_validation_regex         = "^[a-zA-Z0-9._-]+$"
        validation_regex_error_message = "Only alphanumeric characters, dots, dashes, and underscores are allowed."
      }

      machine_type = {
        display_name    = "Machine Type"
        description     = "STACKIT machine flavor for the runner VM."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(var.machine_type)
      }
    }

    outputs = {
      runner_name = {
        display_name    = "Runner Name"
        type            = "STRING"
        assignment_type = "NONE"
      }

      egress_ip = {
        display_name    = "Runner Egress IP"
        type            = "STRING"
        assignment_type = "NONE"
      }

      server_id = {
        display_name    = "Server ID"
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
