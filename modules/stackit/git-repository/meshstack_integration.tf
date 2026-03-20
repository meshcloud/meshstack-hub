# This file is an example showing how to register the STACKIT Git Repository
# building block in a meshStack instance. Adapt backplane outputs and repository
# URL to match your own setup before applying.

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
  })
}

variable "forgejo_token" {
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
  sensitive = false # the whole map is not sensitive, but map values are!
  default   = {}

  validation {
    condition     = alltrue([for key in keys(var.action_secrets) : length(key) <= 30])
    error_message = "Forgejo Actions secret names must be 30 characters or less."
  }
}

variable "action_variables" {
  type    = map(string)
  default = {}
}

variable "stackit_project_id" {
  type        = string
  description = "STACKIT project ID hosting the shared Forgejo instance. Used for project role assignments."
}

variable "stackit_service_account_key" {
  type        = string
  sensitive   = true
  description = "STACKIT service account key used to authenticate the STACKIT provider in the git-repository building block."
}

variable "workspace_members" {
  description = "Workspace members that should receive repository access. Populated via USER_PERMISSIONS assignment on each building block instance."
  type = list(object({
    meshIdentifier = string
    username       = string
    firstName      = string
    lastName       = string
    email          = string
    euid           = string
    roles          = list(string)
  }))
  default = []
}

variable "hub" {
  type = object({
    git_ref   = optional(string, "main")
    bbd_draft = optional(bool, true)
  })
  default     = {}
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
  description = "BBD is consumed in Building Block compositions, for example in the backplane of starter kits."
}

module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/git-repository/backplane?ref=feature/ske-starter-kit-harbor-integration"

  forgejo_base_url     = var.forgejo_base_url
  forgejo_token        = var.forgejo_token
  forgejo_organization = var.forgejo_organization
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
  }

  spec = {
    display_name     = "STACKIT Git Repository"
    symbol           = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/stackit/git-repository/buildingblock/logo.png"
    description      = "Provisions a Git repository on STACKIT Git (Forgejo) with optional clone_addr for one-time cloning from any public Git URL."
    support_url      = "https://git-service.git.onstackit.cloud"
    target_type      = "WORKSPACE_LEVEL"
    run_transparency = true
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"

    implementation = {
      terraform = {
        terraform_version              = "1.9.0"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/stackit/git-repository/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      # ── Static inputs from backplane ──────────────────────────────────────

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
            secret_value = var.forgejo_token
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

      STACKIT_SERVICE_ACCOUNT_KEY = {
        display_name    = "STACKIT_SERVICE_ACCOUNT_KEY"
        description     = "Service account key used for STACKIT provider authentication in this building block."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        sensitive = {
          argument = {
            secret_value = var.stackit_service_account_key
          }
        }
      }

      stackit_project_id = {
        display_name    = "STACKIT Project ID"
        description     = "STACKIT project ID hosting the shared Forgejo instance for role assignments."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.stackit_project_id)
      }

      workspace_identifier = {
        display_name    = "Workspace Identifier"
        type            = "STRING"
        assignment_type = "WORKSPACE_IDENTIFIER"
      }

      workspace_members = {
        display_name    = "Workspace Members"
        description     = "Workspace members used to reconcile Forgejo repository collaborators."
        type            = "CODE"
        assignment_type = "USER_PERMISSIONS"
      }

      # ── User inputs ────────────────────────────────────────────────────────

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
        default_value   = jsonencode("null")
      }


      action_variables = {
        display_name    = "Repository Action Variables"
        description     = "Static non-sensitive map of Forgejo Actions variables created in each provisioned repository."
        type            = "CODE"
        assignment_type = "STATIC"
        # jsonencode twice is correct, see https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block_definition#argument-1
        argument = jsonencode(jsonencode(var.action_variables))
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
  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = "~> 0.20.0"
    }
  }
}
