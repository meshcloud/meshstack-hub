variable "external_service_account" {
  type        = bool
  nullable    = false
  default     = false
  description = "When true, skip the backplane and take the automation identity as the order-time `STACKIT_SERVICE_ACCOUNT_EMAIL` input."

  validation {
    condition     = var.external_service_account || (var.stackit_backplane_project_id != null && var.stackit_backplane_folder_id != null)
    error_message = "stackit_backplane_project_id and stackit_backplane_folder_id are required unless external_service_account is true."
  }
}

variable "stackit_backplane_project_id" {
  type        = string
  nullable    = true
  default     = null
  description = "Existing STACKIT project the backplane creates the automation service account in. Null when external_service_account is true."
}

variable "stackit_backplane_folder_id" {
  type        = string
  nullable    = true
  default     = null
  description = "STACKIT resource-manager folder (`folder_id`, not container_id) the automation service account is granted roles on. Null when external_service_account is true."
}

variable "stackit_region" {
  type        = string
  nullable    = false
  default     = "eu01"
  description = "STACKIT region the Git instance is placed in."
}

variable "roles" {
  type        = list(string)
  nullable    = false
  default     = ["git.admin"]
  description = "Roles granted to the backplane service account on the folder, inherited by the project the Git instance is created in. `git.admin` is the narrow STACKIT Git role and is assignable at folder scope; `git.reader` is the read-only variant."
}

variable "stackit_service_account_name" {
  type        = string
  nullable    = false
  default     = "mesh-stackit-git"
  description = "Name of the backplane automation service account. Unique within the backplane project and capped at 20 characters by STACKIT, so a composition that registers this definition more than once in the same project (e.g. one STACKIT Kubernetes Platform per ordered platform) has to vary it."
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
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/git/backplane?ref=${var.hub.git_ref}"

  enabled = !var.external_service_account

  project_id           = var.stackit_backplane_project_id
  folder_id            = var.stackit_backplane_folder_id
  roles                = var.roles
  service_account_name = var.stackit_service_account_name

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
    display_name        = coalesce(var.bbd_display_name, "STACKIT Git Instance")
    symbol              = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/stackit/git/buildingblock/logo.png"
    description         = coalesce(var.bbd_description, "Provisions a STACKIT Git (Forgejo) instance and, once a bot token exists, the organization repositories are created in.")
    support_url         = "https://portal.stackit.cloud/git"
    target_type         = "TENANT_LEVEL"
    run_transparency    = true
    supported_platforms = [{ name = "STACKIT" }]

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
      Provisions a **STACKIT Git** instance — a managed Forgejo — in this project, and the Forgejo
      organization that application repositories are created in.

      ## 🎯 When to use it

      Use this building block when a platform team needs a Git instance of its own to hand out
      repositories from — for example the **STACKIT Kubernetes Platform** reference architecture,
      which runs application CI/CD on Forgejo Actions against this instance.

      ## 📦 Resources created

      - **STACKIT Git instance** – reachable at `https://<instance name>.git.onstackit.cloud`. The
        name is globally unique across all of STACKIT, so derive it from something already unique.
      - **Forgejo organization** – created only once a Personal Access Token is supplied.

      ## 🔑 The token is handed in, for now

      A fresh instance has no credential yet, so the first order leaves the **Forgejo API Token**
      input empty and creates only the instance. Open the instance URL it reports, sign in, create a
      bot account and mint a Personal Access Token with the `write:organization` scope, then update
      this building block with that token. The next run creates the organization.

      This step is automatable — the STACKIT Git API can create a local user whose password mints
      the token — but that path is not wired up yet. See the building block's README.

      ## 📊 Shared responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Provide the STACKIT project the instance runs in | ✅ | ❌ |
      | Mint and rotate the bot account's Personal Access Token | ✅ | ❌ |
      | Manage the organization and its teams | ✅ | ❌ |
      | Develop and maintain code in the repositories | ❌ | ✅ |
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
        repository_path                = "modules/stackit/git/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      # ── STACKIT authentication (Workload Identity Federation, no key) ──
      STACKIT_SERVICE_ACCOUNT_EMAIL = {
        display_name    = "STACKIT Service Account Email"
        description     = "Email of the STACKIT service account the provider authenticates as via WIF."
        type            = "STRING"
        assignment_type = var.external_service_account ? "USER_INPUT" : "STATIC"
        is_environment  = true
        argument        = var.external_service_account ? null : jsonencode(module.backplane.service_account_email)
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

      # ── Instance placement ──
      stackit_project_id = {
        display_name    = "STACKIT Project ID"
        description     = "STACKIT project the Git instance is created in — the platform-native tenant id of the tenant this building block is added to."
        type            = "STRING"
        assignment_type = "PLATFORM_TENANT_ID"
      }

      stackit_region = {
        display_name    = "STACKIT Region"
        description     = "STACKIT region the Git instance is placed in."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.stackit_region)
      }

      instance_name = {
        display_name                   = "Instance Name"
        description                    = "First label of the instance hostname `<name>.git.onstackit.cloud`, globally unique across all of STACKIT."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$"
        validation_regex_error_message = "Instance name must be a DNS label: lowercase alphanumeric or dashes, not starting or ending with a dash."
      }

      # ── Forgejo organization (created only once a token exists) ──
      # The organization is named after the workspace that ordered the instance, so nothing has to be
      # typed in and two workspaces cannot collide on one instance.
      forgejo_organization = {
        display_name    = "Forgejo Organization"
        description     = "Organization created inside the instance. Named after the ordering workspace."
        type            = "STRING"
        assignment_type = "WORKSPACE_IDENTIFIER"
      }

      forgejo_token = {
        display_name = "Forgejo API Token"
        description  = "Personal Access Token of a bot account in this instance, scope `write:organization`. Leave empty on the first order — the instance has to exist before a token can be minted in it."
        type         = "STRING"
        # Optional so the first order succeeds without it; `sensitive = {}` makes it a secret the
        # consumer types, not a value stored on the definition.
        assignment_type = "USER_INPUT"
        is_optional     = true
        sensitive       = {}
      }
    }

    outputs = {
      instance_name = {
        display_name    = "Instance Name"
        type            = "STRING"
        assignment_type = "NONE"
      }

      instance_url = {
        display_name    = "Open Forgejo"
        type            = "STRING"
        assignment_type = "RESOURCE_URL"
      }

      forgejo_organization = {
        display_name    = "Forgejo Organization"
        type            = "STRING"
        assignment_type = "NONE"
      }

      forgejo_token_provided = {
        display_name    = "Forgejo Token Provided"
        type            = "BOOLEAN"
        assignment_type = "NONE"
      }
    }

    permissions = []
  }
}

terraform {
  required_version = ">= 1.12.0"

  required_providers {
    meshstack = {
      source = "meshcloud/meshstack"
      # 0.25.2 adds `version_spec.inputs.*.is_optional`, which is what lets the first order skip the
      # Forgejo token.
      version = ">= 0.25.2"
    }
  }
}
