variable "stackit_region" {
  type        = string
  nullable    = false
  default     = "eu01"
  description = "STACKIT region the registry is placed in."
}

variable "role_mapping" {
  type     = map(list(string))
  nullable = false
  default = {
    admin  = ["container-registry.artifactory.admin"]
    user   = ["container-registry.artifactory.developer"]
    reader = ["container-registry.artifactory.guest"]
  }
  description = "Maps meshStack project roles to STACKIT container registry roles. Unknown roles are ignored."
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
      - **Access for the project's users** – every meshStack user on the project is granted the
        matching STACKIT registry role, which is what makes the Harbor project visible to them.

      ## 👤 Signing in

      Open `registry.onstackit.cloud` and sign in with your STACKIT account. Harbor creates the
      account on first sign-in; the project appears because of the role this building block granted.

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
        pre_run_script                 = file("${path.module}/buildingblock/prerun.sh")
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

      stackit_region = {
        display_name    = "STACKIT Region"
        description     = "Region the registry is placed in."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.stackit_region)
      }

      users = {
        display_name    = "Users"
        description     = "Project users with role assignments from meshStack."
        type            = "CODE"
        assignment_type = "USER_PERMISSIONS"
      }

      role_mapping = {
        display_name    = "Role Mapping"
        description     = "HCL object mapping meshStack project roles to STACKIT container registry roles."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.role_mapping))
      }

      registry_name = {
        display_name                   = "Registry Name"
        description                    = "Base name of the container registry. A short random suffix is appended, because STACKIT keeps a deleted registry's name reserved."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[a-z0-9][a-z0-9-]{3,56}[a-z0-9]$"
        validation_regex_error_message = "Registry name must be 5 to 58 characters, lowercase alphanumeric or dashes, and not start or end with a dash."
      }

      # The registry is ordered before the robot it is told about exists, so the name arrives on a
      # later update and the block has to accept it changing after it was first ordered.
      bootstrap_robot_username = {
        display_name           = "Bootstrap Robot Name"
        description            = "Name of a Harbor robot in this registry, linked to this platform's STACKIT service account. Only the Harbor UI can create the first one; leave empty until you have. Its password is not needed."
        type                   = "STRING"
        assignment_type        = "USER_INPUT"
        is_optional            = true
        updateable_by_consumer = true
      }

      mirrored_base_images = {
        display_name           = "Mirrored Base Images"
        description            = "HCL list of fully qualified upstream images to mirror into the registry as `<registry>/<name>:<tag>`. Mirroring starts once the bootstrap robot is set."
        type                   = "CODE"
        assignment_type        = "USER_INPUT"
        default_value          = jsonencode(jsonencode([]))
        updateable_by_consumer = true
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

      registry_robot_url = {
        display_name    = "Registry Robot URL"
        type            = "STRING"
        assignment_type = "NONE"
      }

      access_credentials = {
        display_name    = "Access Credentials"
        type            = "CODE"
        assignment_type = "NONE"
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
      version = ">= 0.25.2"
    }
  }
}
