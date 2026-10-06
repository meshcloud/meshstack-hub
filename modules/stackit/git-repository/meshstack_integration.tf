variable "forgejo_organization" {
  type = string
}

variable "forgejo_base_url" {
  type = string
}

variable "vault_reader" {
  type = object({
    address  = string
    mount    = string
    username = string
    password = string
  })
  nullable    = false
  sensitive   = true
  description = "Vault KV v2 login the building blocks read their secrets with: the server `address`, the engine `mount` and a userpass `username` and `password`."
}

variable "forgejo_api_token_path" {
  type        = string
  nullable    = false
  description = "Vault KV v2 secret holding the Forgejo API token under the key `forgejo_api_token`. The token needs the write:repository and write:organization scopes."
}

variable "registry_push_path" {
  type        = string
  default     = null
  description = "Vault KV v2 secret holding a container registry push robot under the keys `username` and `password`, set on every repository as the Actions secrets `HARBOR_USERNAME` and `HARBOR_PASSWORD`. Null sets neither."
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

variable "approval_policies" {
  type = object({
    building_block_creation = optional(bool, false)
    user_input_changes      = optional(bool, false)
    any_input_changes       = optional(bool, false)
    manual_triggers         = optional(bool, false)
    version_upgrade         = optional(bool, false)
  })
  nullable    = false
  default     = {}
  description = "Run triggers that need an operator's approval before a run of this definition is applied. A gate switched on in meshPanel is reset on the next apply unless it is set here."
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
    display_name = coalesce(var.bbd_display_name, "STACKIT Git Repository")
    symbol       = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/stackit/git-repository/buildingblock/logo.png"
    description = coalesce(var.bbd_description, chomp(<<-EOT
      Provisions a Git repository on STACKIT Git (Forgejo) with team-based
      workspace member access management.
    EOT
    ))
    support_url       = "https://git-service.git.onstackit.cloud"
    target_type       = "WORKSPACE_LEVEL"
    run_transparency  = true
    approval_policies = var.approval_policies

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
    - **Action secrets & variables** – Forgejo Actions variables set by the platform and by you, and the
      container registry push robot as the secrets `HARBOR_USERNAME` and `HARBOR_PASSWORD` where the
      platform offers one, managed via the REST API (see below).

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
    | Provide the Forgejo API token and the registry push robot | ✅ | ❌ |
    | Manage further repository secrets and variables | ❌ | ✅ |
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

    inputs = merge({
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

      vault_reader = {
        display_name    = "Vault Reader"
        description     = "HCL object `{address, mount, username, password}` of the Vault KV v2 login the run reads its secrets with."
        type            = "CODE"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value   = jsonencode(var.vault_reader)
            secret_version = nonsensitive(sha256(jsonencode(var.vault_reader)))
          }
        }
      }

      forgejo_api_token_path = {
        display_name    = "Forgejo API Token Path"
        description     = "Vault KV v2 secret holding the Forgejo API token under the key `forgejo_api_token`."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.forgejo_api_token_path)
      }

      forgejo_organization = {
        display_name    = "STACKIT Git Forgejo Organization"
        description     = "Organization under which repositories will be created in Forgejo"
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.forgejo_organization)
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
      }, var.registry_push_path == null ? {} : {
      registry_push_path = {
        display_name    = "Registry Push Robot Path"
        description     = "Vault KV v2 secret holding the push robot set as the Actions secrets `HARBOR_USERNAME` and `HARBOR_PASSWORD`."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.registry_push_path)
      }
    })

    outputs = {
      repository_id = {
        display_name    = "Repository ID"
        type            = "INTEGER"
        assignment_type = "NONE"
        description     = "Numeric Forgejo repository ID, primarily intended for wiring dependent building blocks."
      }

      repository_owner = {
        display_name    = "Repository Owner"
        type            = "STRING"
        assignment_type = "NONE"
        description     = "Forgejo organization that owns the repository."
      }

      repository_name = {
        display_name    = "Repository Name"
        type            = "STRING"
        assignment_type = "NONE"
        description     = "Name of the repository."
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
      source = "meshcloud/meshstack"
      # 0.25.2 is the first release that accepts `spec.approval_policies`.
      version = ">= 0.25.2"
    }
  }
}
