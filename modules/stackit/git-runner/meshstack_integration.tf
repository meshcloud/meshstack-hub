variable "stackit_project_id" {
  type        = string
  description = "STACKIT project ID the runner VM is created in and the backplane service account is granted on."
}

variable "stackit_region" {
  type        = string
  default     = "eu01"
  description = "STACKIT region for the VM and its network resources."
}

variable "image_id" {
  type        = string
  description = "STACKIT image UUID to boot the runner from (Ubuntu 22.04 recommended). Region-specific."
}

variable "network_id" {
  type        = string
  default     = null
  description = "Existing STACKIT network to attach the runner to. Leave null to create a dedicated one."
}

variable "machine_type" {
  type        = string
  default     = "c1.2"
  description = "STACKIT machine flavor for the runner VM."
}

variable "runner_labels" {
  type        = list(string)
  description = "STACKIT Git Actions runner labels, each <label>:host or <label>:docker://<image>. Referenced by workflows via runs-on."
  default = [
    "self-hosted:host",
    "stackit-docker:docker://code.forgejo.org/oci/node:20-bookworm",
  ]
}

variable "git_base_url" {
  type        = string
  description = "Base URL of the STACKIT Git instance, e.g. https://<name>.git.onstackit.cloud."
}

variable "git_organization" {
  type        = string
  description = "STACKIT Git organization the runner is registered for."
}

variable "git_token" {
  type        = string
  sensitive   = true
  description = "STACKIT Git PAT with org-admin rights on var.git_organization — mints the runner registration token."
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
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  }
  description = "BBD is consumed in Building Block compositions, for example in a reference architecture."
}

data "meshstack_integrations" "integrations" {}

module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/git-runner/backplane?ref=${var.hub.git_ref}"

  project_id = var.stackit_project_id

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
    display_name = coalesce(var.bbd_display_name, "STACKIT Git Runner")
    symbol       = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/stackit/git-runner/buildingblock/logo.png"
    description = coalesce(var.bbd_description, chomp(<<-EOT
      Deploys a STACKIT VM running a self-hosted STACKIT Git Actions runner at organization scope.
    EOT
    ))
    support_url      = var.git_base_url
    target_type      = "WORKSPACE_LEVEL"
    run_transparency = true

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
    The **STACKIT Git Runner** building block deploys a self-hosted CI runner for STACKIT Git on a
    STACKIT VM, so pipelines in an organization's repositories can run immediately instead of waiting
    on STACKIT's order-based managed runners.

    ## 📦 What it provisions

    - A **STACKIT VM** (server, network, network interface, SSH key pair) provisioned via cloud-init
      on first boot. The VM has **no inbound public IP** — it reaches the Git instance through the
      network router's outbound NAT.
    - A **STACKIT Git Actions runner** installed and run as a systemd daemon, registered at
      **organization scope** — one runner serves every repository in the organization.

    The registration token is minted at run time via the STACKIT Git API using an org-admin PAT and
    never stored on the VM. **Prerequisite:** Actions must be enabled on the STACKIT Git instance.

    ## 🏷️ Using it in workflows

    Target the runner from a workflow with its labels, e.g. `runs-on: stackit-docker`.

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
        description     = "Project the runner VM is created in."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.stackit_project_id)
      }

      stackit_region = {
        display_name    = "STACKIT Region"
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.stackit_region)
      }

      image_id = {
        display_name    = "Image ID"
        description     = "STACKIT image UUID to boot the runner from."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.image_id)
      }

      network_id = {
        display_name    = "Network ID"
        description     = "Existing STACKIT network to attach to, or null to create one."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.network_id)
      }

      runner_labels = {
        display_name    = "Runner Labels"
        description     = "STACKIT Git Actions runner labels referenced by workflows via runs-on."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.runner_labels))
      }

      git_base_url = {
        display_name    = "STACKIT Git Base URL"
        description     = "Base URL of the STACKIT Git instance."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.git_base_url)
      }

      git_organization = {
        display_name    = "STACKIT Git Organization"
        description     = "Organization the runner is registered for."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.git_organization)
      }

      git_token = {
        display_name    = "STACKIT Git PAT"
        description     = "Org-admin PAT used to mint the runner registration token."
        type            = "STRING"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value = var.git_token
          }
        }
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
        default_value   = jsonencode("c1.2")
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
