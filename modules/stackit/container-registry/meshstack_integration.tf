variable "stackit_backplane_project_id" {
  type        = string
  nullable    = false
  description = "Existing STACKIT project the backplane creates the automation service account in."
}

variable "stackit_backplane_folder_id" {
  type        = string
  nullable    = false
  description = "STACKIT resource-manager folder (`folder_id`, not container_id) the automation service account is granted roles on."
}

variable "stackit_region" {
  type        = string
  nullable    = false
  default     = "eu01"
  description = "STACKIT region the registry is placed in."
}

variable "roles" {
  type        = list(string)
  nullable    = false
  default     = ["editor", "container-registry.admin"]
  description = "Roles granted to the backplane service account on the folder. `editor` carries `service-enablement.service-state.edit`, `container-registry.admin` carries `container-registry.project.create`."
}

variable "stackit_service_account_name" {
  type        = string
  nullable    = false
  default     = "mesh-stackit-cr"
  description = "Name of the backplane automation service account, capped at 20 characters by STACKIT."
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

data "meshstack_integrations" "integrations" {}

module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/container-registry/backplane?ref=${var.hub.git_ref}"

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
    display_name        = coalesce(var.bbd_display_name, "STACKIT Container Registry")
    symbol              = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/stackit/container-registry/buildingblock/logo.png"
    description         = coalesce(var.bbd_description, "Provisions a STACKIT container registry (Harbor) in this project, so application images have somewhere to live.")
    support_url         = "https://portal.stackit.cloud"
    target_type         = "TENANT_LEVEL"
    run_transparency    = true
    supported_platforms = [{ name = "STACKIT" }]

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
      Provisions a **STACKIT container registry** — a managed Harbor — in this project, so
      application images have somewhere to live.

      ## 🎯 When to use it

      Use this building block when a platform team needs a registry of its own to push application
      images to — for example the **STACKIT Kubernetes Platform** reference architecture, whose CI
      builds images and whose workloads pull them back.

      ## 📦 Resources created

      - **Service enablement** – `cloud.stackit.container-registry` is disabled by default on a
        fresh STACKIT project, so it is switched on first.
      - **Registry** – reachable at `registry.onstackit.cloud/<registry name>`.

      ## 🤖 One manual step, once per registry

      STACKIT grants no IAM role that opens the Harbor API to an identity Harbor does not already
      know. Access comes from linking a robot account to a STACKIT service account, and only the
      portal can create that first link. The building block's summary says exactly what to click.

      Once linked, that service account's token authenticates as the robot, so every later robot
      can be created through the Harbor API without touching the portal again.

      ## 📊 Shared responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Provide the STACKIT project the registry runs in | ✅ | ❌ |
      | Create and link the first robot account | ✅ | ❌ |
      | Manage image retention and vulnerability policies | ✅ | ❌ |
      | Push and pull application images | ❌ | ✅ |
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
        repository_path                = "modules/stackit/container-registry/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      stackit_project_id = {
        display_name    = "STACKIT Project ID"
        description     = "STACKIT project the registry is created in."
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

      stackit_region = {
        display_name    = "STACKIT Region"
        description     = "Region the registry is placed in."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.stackit_region)
      }

      registry_name = {
        display_name                   = "Registry Name"
        description                    = "Name of the container registry to create in the project."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$"
        validation_regex_error_message = "Registry name must be lowercase alphanumeric or dashes, and not start or end with a dash."
      }
    }

    outputs = {
      registry_name = {
        display_name    = "Registry Name"
        type            = "STRING"
        assignment_type = "NONE"
      }

      registry_host = {
        display_name    = "Registry Host"
        type            = "STRING"
        assignment_type = "NONE"
      }

      registry_url = {
        display_name    = "Open Registry"
        type            = "STRING"
        assignment_type = "RESOURCE_URL"
      }

      summary = {
        display_name    = "Summary"
        type            = "STRING"
        assignment_type = "SUMMARY"
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
      version = ">= 0.21.0"
    }
    stackit = {
      source  = "stackitcloud/stackit"
      version = ">= 0.98.0, < 1.0.0"
    }
  }
}
