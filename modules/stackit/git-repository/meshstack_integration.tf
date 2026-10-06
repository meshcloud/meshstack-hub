variable "forgejo_api_token" {
  type      = string
  sensitive = true
}

variable "forgejo_organization" {
  type = string
}

variable "forgejo_base_url" {
  type = string
}

variable "action_secrets" {
  type      = map(string)
  default   = {}
  sensitive = true

  validation {
    condition     = alltrue([for key in keys(nonsensitive(var.action_secrets)) : (length(key) <= 30)])
    error_message = "Forgejo Actions secret names must be 30 characters or less."
  }
}

variable "action_variables" {
  type    = map(string)
  default = {}
}

variable "stackit_service_account_email" {
  type        = string
  description = "Service account the runs act as via WIF to list STACKIT Git users. It must federate this definition."
}

variable "stackit_project_id" {
  type        = string
  description = "STACKIT project of the Git instance."
}

variable "stackit_git_instance_id" {
  type        = string
  description = "STACKIT Git instance whose users are matched to workspace members by email."
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

module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/git-repository/backplane?ref=${var.hub.git_ref}"

  forgejo_base_url     = var.forgejo_base_url
  forgejo_api_token    = var.forgejo_api_token
  forgejo_organization = var.forgejo_organization
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name = coalesce(var.bbd_display_name, "STACKIT Git Repository")
    symbol       = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/stackit/git-repository/buildingblock/logo.png"
    description = coalesce(var.bbd_description, chomp(<<-EOT
      Provisions a Git repository on STACKIT Git (Forgejo) with team-based
      workspace member access management.
    EOT
    ))
    support_url      = "https://git-service.git.onstackit.cloud"
    target_type      = "WORKSPACE_LEVEL"
    run_transparency = true

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
    The **STACKIT Git Repository** building block creates a Forgejo repository on STACKIT Git and manages
    workspace member access using Forgejo organization teams.

    ## 📦 Resources Created

    - **Forgejo repository** – created under a configurable Forgejo organization. Optionally cloned from an
      existing public Git URL (one-time clone, not an ongoing mirror).
    - **Forgejo teams** – workspace members are organized into organization teams by role
      (Owner → admins/admin, Manager → writers/write, others → readers/read).
      Teams are assigned to the repository with appropriate permissions.
    - **Team members** – workspace members who have signed in to the STACKIT Git instance once are added
      to their team, matched by email through the STACKIT Git API.
    - **Action secrets & variables** – optional maps of Forgejo Actions secrets and variables managed via the
      REST API (see below).

    ## ℹ️ Forgejo Actions secrets & variables

    The Forgejo Terraform provider currently cannot delete action secrets (only removes them from state) and
    does not support action variables at all. This building block therefore manages them via the generic
    `restapi` provider against the Forgejo API, ensuring proper create/update/delete lifecycle.

    ## 📊 Shared Responsibility

    | Responsibility | Platform Team | Application Team |
    |---|:---:|:---:|
    | Provision and manage the Forgejo repository | ✅ | ❌ |
    | Manage organization teams and access control | ✅ | ❌ |
    | Develop and maintain code in the repository | ❌ | ✅ |
    | Configure Forgejo Actions pipelines | ❌ | ✅ |
    | Manage repository secrets and variables | ❌ | ✅ |
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
        repository_path                = "modules/stackit/git-repository/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      STACKIT_SERVICE_ACCOUNT_EMAIL = {
        display_name    = "STACKIT Service Account Email"
        description     = "Email of the STACKIT service account the run authenticates as via WIF to list STACKIT Git users."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(var.stackit_service_account_email)
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
        description     = "STACKIT project of the Git instance."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.stackit_project_id)
      }

      stackit_git_instance_id = {
        display_name    = "STACKIT Git Instance ID"
        description     = "STACKIT Git instance whose users are matched to workspace members by email."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.stackit_git_instance_id)
      }

      hub_git_ref = {
        display_name    = "hub_git_ref"
        description     = "Hub git ref this building block runs from."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.hub.git_ref)
      }

      FORGEJO_HOST = {
        display_name    = "FORGEJO_HOST"
        description     = "The Host of the Forgejo instance to connect to."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(var.forgejo_base_url)
      }

      FORGEJO_API_TOKEN = {
        display_name    = "FORGEJO_API_TOKEN"
        description     = "The API token for authenticating with the Forgejo instance."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        sensitive = {
          argument = {
            secret_value   = var.forgejo_api_token
            secret_version = nonsensitive(sha256(var.forgejo_api_token))
          }
        }
      }

      forgejo_organization = {
        display_name    = "STACKIT Git Forgejo Organization"
        description     = "Organization under which repositories will be created in Forgejo"
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(module.backplane.forgejo_organization)
      }

      workspace_identifier = {
        display_name    = "Workspace Identifier"
        type            = "STRING"
        assignment_type = "WORKSPACE_IDENTIFIER"
      }

      workspace_members = {
        display_name    = "Workspace Members"
        description     = "Workspace members used to manage Forgejo team membership."
        type            = "CODE"
        assignment_type = "USER_PERMISSIONS"
      }

      name = {
        display_name                   = "Repository Name / Identifier"
        description                    = "Name of the Git repository (alphanumeric, dashes, dots, underscores)"
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[a-zA-Z0-9._-]+$"
        validation_regex_error_message = "Only alphanumeric characters, dots, dashes, and underscores are allowed."
      }

      description = {
        display_name           = "Repository Description"
        description            = "Short description of the repository."
        type                   = "STRING"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        default_value          = jsonencode("")
      }

      private = {
        display_name           = "Private Repository"
        description            = "If true, the repository has private visibility in Forgejo."
        type                   = "BOOLEAN"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        default_value          = jsonencode(true)
      }

      clone_addr = {
        display_name    = "Clone from URL"
        description     = "Optional URL to clone into this repository, e.g. 'https://github.com/owner/repo.git'. Leave `null` to create an empty repository."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        # The Panel UI does not support an empty string as the default of an optional value.
        default_value = jsonencode("null")
      }

      default_branch = {
        display_name    = "Default Branch"
        description     = "Default branch of an empty repository; a clone keeps the source's."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode("main")
      }

      action_variables = {
        display_name    = "Repository Action Variables"
        description     = "Static non-sensitive map of Forgejo Actions variables created in each provisioned repository."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.action_variables))
      }

      extra_action_variables = {
        display_name           = "Extra Action Variables"
        description            = "HCL map of Forgejo Actions variables for this repository only, merged over the platform-wide ones."
        type                   = "CODE"
        assignment_type        = "USER_INPUT"
        default_value          = jsonencode(jsonencode({}))
        updateable_by_consumer = true
      }

      action_secrets = {
        display_name    = "Repository Action Secrets"
        description     = "Static sensitive map of Forgejo Actions secrets created in each provisioned repository."
        type            = "CODE"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value   = jsonencode(var.action_secrets)
            secret_version = nonsensitive(sha256(jsonencode(var.action_secrets)))
          }
        }
      }
    }

    outputs = {
      repository_id = {
        display_name    = "Repository ID"
        type            = "INTEGER"
        assignment_type = "NONE"
        description     = "Numeric Forgejo repository ID, primarily intended for wiring dependent building blocks."
      }

      repository_html_url = {
        display_name    = "Open Repository"
        type            = "STRING"
        assignment_type = "RESOURCE_URL"
      }

      repository_clone_url = {
        display_name    = "HTTPS Clone URL"
        type            = "STRING"
        assignment_type = "NONE"
      }

      repository_ssh_url = {
        display_name    = "SSH Clone URL"
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
