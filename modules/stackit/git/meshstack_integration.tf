variable "stackit_region" {
  type        = string
  nullable    = false
  default     = "eu01"
  description = "STACKIT region the Git instance is placed in."
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
    version_ref = meshstack_building_block_definition.this.version_latest
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
    description         = coalesce(var.bbd_description, "Provisions a STACKIT Git (Forgejo) instance and the organization repositories are created in.")
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
      - **Forgejo organization** – application repositories are created in it.
      - **Technical user and its API token** – how the building block reaches the Forgejo API.

      ## 🔑 The token mints itself

      A fresh instance carries no credential, so the building block makes one: it switches on local
      login, creates a technical user through the STACKIT Git API, and exchanges that user's password
      for a Personal Access Token. Ordering it takes one run and no manual step.

      The token is reported as an output, so building blocks that manage repositories, runners or
      organization members take it from here.

      ## 📊 Shared responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Provide the STACKIT project the instance runs in | ✅ | ❌ |
      | Mint and rotate the technical user's Personal Access Token | ✅ | ❌ |
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

      forgejo_organization = {
        display_name                   = "Forgejo Organization"
        description                    = "Organization created inside the instance."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        updateable_by_consumer         = true
        value_validation_regex         = "^[a-zA-Z0-9]([a-zA-Z0-9._-]{0,38}[a-zA-Z0-9])?$"
        validation_regex_error_message = "Organization name must be 1-40 characters of letters, digits, dots, dashes or underscores, and not start or end with a separator."
      }

      shared_runner_labels = {
        display_name           = "Shared Runner Labels"
        description            = "HCL list of labels of the STACKIT-hosted shared runner to order. Leave empty to order none."
        type                   = "CODE"
        assignment_type        = "USER_INPUT"
        default_value          = jsonencode(jsonencode([]))
        updateable_by_consumer = true
      }

      local_user_username = {
        display_name    = "Technical User"
        description     = "Username of the technical user the building block mints its token on."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode("meshstack-bot")
      }

      local_user_email = {
        display_name    = "Technical User Email"
        description     = "Email of the technical user. Empty derives one from the instance hostname."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode("")
      }

      local_user_token_name = {
        display_name    = "Technical User Token Name"
        description     = "Name of the Personal Access Token the building block mints."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode("meshstack-buildingblock")
      }

      local_user_token_scopes = {
        display_name    = "Technical User Token Scopes"
        description     = "Forgejo scopes of the minted token."
        type            = "CODE"
        assignment_type = "STATIC"
        argument = jsonencode(jsonencode([
          "write:organization",
          "write:repository",
          "write:user",
        ]))
      }
    }

    outputs = {
      instance_name = {
        display_name    = "Instance Name"
        type            = "STRING"
        assignment_type = "NONE"
      }

      instance_url = {
        display_name    = "Instance URL"
        type            = "STRING"
        assignment_type = "NONE"
      }

      organization_url = {
        display_name    = "Open Forgejo Org"
        type            = "STRING"
        assignment_type = "RESOURCE_URL"
      }

      forgejo_organization = {
        display_name    = "Forgejo Organization"
        type            = "STRING"
        assignment_type = "NONE"
      }

      forgejo_api_token = {
        display_name    = "Forgejo API Token"
        type            = "STRING"
        assignment_type = "NONE"
      }

      local_user_username = {
        display_name    = "Technical User"
        type            = "STRING"
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
      source  = "meshcloud/meshstack"
      version = ">= 0.25.2"
    }
  }
}
