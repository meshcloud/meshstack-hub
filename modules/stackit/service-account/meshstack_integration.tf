variable "stackit_organization_id" {
  type        = string
  description = "STACKIT organization ID under which target projects live."
}

variable "stackit_project_id" {
  type        = string
  description = "STACKIT project ID where the backplane service account will be created."
}

variable "stackit_service_account_name" {
  type        = string
  default     = null
  description = "Name of the backplane service account. Defaults to 'mesh-service-account'. Override when deploying multiple backplane instances in the same STACKIT project."
}

variable "stackit_assignable_roles" {
  type        = list(string)
  default     = ["reader", "editor"]
  description = "STACKIT project roles application teams may grant the service account. Constrains the `roles` input offered in the catalog."
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
  description = "Shared meshStack context."
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
    # Other workspaces may only order a released version. Null until the first release.
    version_ref_release = meshstack_building_block_definition.this.version_latest_release
  }
}

locals {
  # STACKIT role names may contain dots — `ske.admin` is the first one that does. The roles are
  # joined into the catalog's `roles` validation alternation, where an unescaped dot matches any
  # character, so `skeXadmin` would pass validation for a role nobody granted.
  assignable_roles_pattern = join("|", [for role in var.stackit_assignable_roles : replace(role, ".", "\\.")])
}

module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/service-account/backplane?ref=${var.hub.git_ref}"

  project_id           = var.stackit_project_id
  organization_id      = var.stackit_organization_id
  service_account_name = coalesce(var.stackit_service_account_name, "mesh-service-account")

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
    display_name        = coalesce(var.bbd_display_name, "STACKIT Service Account")
    symbol              = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/stackit/service-account/buildingblock/logo.png"
    description         = coalesce(var.bbd_description, "Creates a STACKIT service account with project roles.")
    support_url         = "https://portal.stackit.cloud"
    target_type         = "TENANT_LEVEL"
    run_transparency    = true
    supported_platforms = [{ name = "STACKIT" }]
    readme = coalesce(var.bbd_readme, chomp(<<-EOT
      This building block creates a **STACKIT service account** inside your existing STACKIT project,
      and grants it the project roles you choose. To let runs of your workspace's own building block
      definitions act as it, order a **STACKIT Service Account Federation** building block as its
      child.

      ## 🎯 When to use it

      Use this building block when you:
      - Need a machine identity in your STACKIT project for building blocks that act against STACKIT.
      - Want to grant that identity a defined set of project roles rather than reusing a personal account.

      ## 💡 Usage examples

      **Example 1: Identity for a composed platform**
      A composition orders this block with the `editor` role, then a STACKIT Service Account
      Federation block as its child, so the runs of its own definitions act as the new account.

      **Example 2: Reader identity**
      A team creates a service account with the `reader` role and uses it as the principal for
      STACKIT role assignments elsewhere.

      ## 📊 Shared Responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Provide the backplane identity used to create service accounts | ✅ | ❌ |
      | Define which project roles may be granted | ✅ | ❌ |
      | Choose the service account name and roles within the allowed set | ❌ | ✅ |
      | Rotate and manage any credentials derived from the service account | ❌ | ✅ |
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
        repository_path                = "modules/stackit/service-account/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      project_id = {
        display_name    = "STACKIT Project ID"
        description     = "STACKIT project ID of the existing project the service account will be created in."
        type            = "STRING"
        assignment_type = "PLATFORM_TENANT_ID"
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

      service_account_name = {
        display_name    = "Service Account Name"
        description     = "Name of the STACKIT service account to create. Must be unique within the project. Lowercase letters, numbers and dashes; must start with a letter and not start/end with a dash or contain consecutive dashes."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        # STACKIT rejects any other shape at create time; validate at order time so the app team gets
        # the error before a run starts. Anchored, no lookahead: a dash only sits between alphanumerics.
        value_validation_regex         = "^[a-z][a-z0-9]*(-[a-z0-9]+)*$"
        validation_regex_error_message = "Name must start with a lowercase letter and contain only lowercase letters, numbers and single dashes (no leading, trailing or consecutive dashes)."
      }

      roles = {
        display_name                   = "Project Roles"
        description                    = "HCL list of STACKIT project roles to grant the service account. Allowed: ${join(", ", var.stackit_assignable_roles)}."
        type                           = "CODE"
        assignment_type                = "USER_INPUT"
        default_value                  = jsonencode(jsonencode(["reader"]))
        value_validation_regex         = "^\\[\\s*(\"(${local.assignable_roles_pattern})\"\\s*,?\\s*)+\\]$"
        validation_regex_error_message = "roles must be an HCL list containing only: ${join(", ", var.stackit_assignable_roles)}."

        # A composing architecture grows this list as the blocks it orders need more STACKIT
        # permissions, so the block must accept the input changing after it was first ordered.
        updateable_by_consumer = true
      }
    }

    outputs = {
      service_account_url = {
        display_name    = "Service Account URL"
        type            = "STRING"
        assignment_type = "RESOURCE_URL"
      }

      service_account_email = {
        display_name    = "Service Account Email"
        type            = "STRING"
        assignment_type = "NONE"
      }

      service_account_id = {
        display_name    = "Service Account ID"
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
    stackit = {
      source  = "stackitcloud/stackit"
      version = ">= 0.98.0, < 1.0.0"
    }
  }
}
