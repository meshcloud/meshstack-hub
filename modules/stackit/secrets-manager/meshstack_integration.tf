variable "stackit_project_id" {
  type        = string
  description = "STACKIT project ID where Secrets Manager instances will be created."
}

variable "stackit_service_account_name" {
  type        = string
  default     = null
  description = "Name of the backplane service account. Defaults to 'mesh-secrets-manager'. Override when deploying multiple backplane instances in the same STACKIT project."
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

data "meshstack_integrations" "integrations" {}

module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/secrets-manager/backplane?ref=${var.hub.git_ref}"

  project_id           = var.stackit_project_id
  service_account_name = coalesce(var.stackit_service_account_name, "mesh-secrets-manager")

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
    display_name     = coalesce(var.bbd_display_name, "STACKIT Secrets Manager")
    symbol           = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/stackit/secrets-manager/buildingblock/logo.png"
    description      = coalesce(var.bbd_description, "Provisions a STACKIT Secrets Manager instance.")
    target_type      = "WORKSPACE_LEVEL"
    run_transparency = true
    readme = coalesce(var.bbd_readme, chomp(<<-EOT
      This building block provisions a **STACKIT Secrets Manager** instance for your team. It is a
      Vault-compatible key-value store for passwords, API keys and certificates.

      ## 🎯 When to use it

      Use this building block when your application team needs:
      - A central place for application secrets instead of config files or CI variables.
      - A secret store your workloads can read with the standard Vault CLI or API.

      ## 💡 Usage examples

      **Example 1: Database credentials for a backend service**
      A developer stores the database password in the instance. The backend service reads it at
      startup through the Vault API.

      **Example 2: Secrets for a CI pipeline**
      A pipeline logs in with a read-only user and fetches deployment tokens, so no token is
      stored in the CI system itself.

      ## 📊 Shared Responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Provision the Secrets Manager instance | ✅ | ❌ |
      | Choose the instance name | ❌ | ✅ |
      | Create users and manage their credentials | ❌ | ✅ |
      | Store, update and delete secrets | ❌ | ✅ |
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
        repository_path                = "modules/stackit/secrets-manager/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      project_id = {
        display_name    = "STACKIT Project ID"
        description     = "STACKIT project ID where the Secrets Manager instance will be created."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(module.backplane.project_id)
      }

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

      instance_name = {
        display_name    = "Instance Name"
        description     = "Name of the Secrets Manager instance."
        type            = "STRING"
        assignment_type = "USER_INPUT"
      }
    }

    outputs = {
      instance_id = {
        display_name    = "Instance ID"
        type            = "STRING"
        assignment_type = "NONE"
      }

      api_url = {
        display_name    = "API URL"
        type            = "STRING"
        assignment_type = "NONE"
      }

      kv_mount = {
        display_name    = "KV Mount"
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
      version = ">= 0.21.0"
    }
  }
}
