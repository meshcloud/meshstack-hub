variable "stackit_project_id" {
  type        = string
  description = "STACKIT project ID where the backplane service account will be created."
}

variable "stackit_organization_id" {
  type        = string
  description = "STACKIT organization ID where the service account will be granted permissions."
}

variable "stackit_parent_container_id" {
  type        = string
  description = "Default parent container ID (organization or folder) for project creation."
}

variable "stackit_service_account_name" {
  type        = string
  default     = null
  description = "Name of the backplane service account. Defaults to 'mesh-project'. Override when deploying multiple backplane instances in the same STACKIT project."
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    tags = optional(object({
      landingzone    = map(list(string))
      building_block = map(list(string))
    }), { landingzone = {}, building_block = {} })
    location_name       = optional(string, "global")
    platform_identifier = optional(string, "stackit")
  })
  description = <<-EOT
  Shared meshStack context.
  `owning_workspace_identifier`: Identifier of the meshStack workspace that owns the managed resources.
  `tags`: Optional tags propagated to building block definition and landing zone metadata.
  `location_name`: meshStack location name for the platform. Defaults to "global".
  `platform_identifier`: Identifier for the platform in meshStack. Defaults to "stackit".
  EOT
}

variable "hub" {
  type = object({
    git_ref   = optional(string, "main")
    bbd_draft = optional(bool, true)
  })
  default     = {}
  description = <<-EOT
  `git_ref`: Hub release reference. Set to a tag (e.g. 'v1.2.3') or branch or commit sha of meshcloud/meshstack-hub repo.
  `bbd_draft`: If true, allows changing the building block definition for upgrading dependent building blocks.
  EOT
}

module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/project/backplane?ref=2f0dff3e7fde31b7a4238b27dd413cb307d2fb19"

  project_id           = var.stackit_project_id
  organization_id      = var.stackit_organization_id
  service_account_name = coalesce(var.stackit_service_account_name, "mesh-project")
}

output "building_block_definition" {
  description = "BBD is consumed in building block compositions."
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  }
}

resource "meshstack_platform_type" "stackit" {
  metadata = {
    name               = "STACKIT"
    owned_by_workspace = var.meshstack.owning_workspace_identifier
  }

  spec = {
    display_name     = "STACKIT"
    default_endpoint = "https://portal.stackit.cloud"
    icon             = "data:image/png;base64,${filebase64("${path.module}/stackit.png")}"
  }
}

resource "meshstack_platform" "stackit" {
  metadata = {
    name               = var.meshstack.platform_identifier
    owned_by_workspace = var.meshstack.owning_workspace_identifier
  }

  spec = {
    display_name = "STACKIT Project"
    description  = "STACKIT. Create a STACKIT project with role-based access control."
    endpoint     = "https://portal.stackit.cloud"

    location_ref = {
      name = var.meshstack.location_name
    }

    availability = {
      restriction              = "PRIVATE"
      publication_state        = "UNPUBLISHED"
      restricted_to_workspaces = [var.meshstack.owning_workspace_identifier]
    }

    config = {
      custom = {
        platform_type_ref = meshstack_platform_type.stackit.ref
      }
    }
  }
}

resource "meshstack_landingzone" "stackit_default" {
  metadata = {
    name               = "${var.meshstack.platform_identifier}-default"
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags.landingzone
  }

  spec = {
    display_name                  = "STACKIT Default"
    description                   = "Default landing zone for STACKIT projects."
    automate_deletion_approval    = true
    automate_deletion_replication = true

    platform_ref = {
      uuid = meshstack_platform.stackit.metadata.uuid
    }

    platform_properties = {
      custom = {}
    }

    mandatory_building_block_refs = [
      { uuid = meshstack_building_block_definition.this.metadata.uuid }
    ]
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags.building_block
  }

  spec = {
    display_name        = "STACKIT Project"
    symbol              = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/stackit/project/buildingblock/logo.png"
    description         = "Creates a new STACKIT project and manages user access permissions with role-based access control."
    support_url         = "https://portal.stackit.cloud"
    target_type         = "TENANT_LEVEL"
    run_transparency    = true
    supported_platforms = [meshstack_platform_type.stackit.ref]
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"

    implementation = {
      terraform = {
        terraform_version              = "1.11.0"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/stackit/project/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      parent_container_id = {
        display_name    = "Parent Container ID"
        description     = "Default parent container ID (organization or folder) where the project will be created."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.stackit_parent_container_id)
      }

      service_account_email = {
        display_name    = "Service Account Email"
        description     = "Email of the STACKIT service account that owns created projects."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(module.backplane.service_account_email)
      }

      service_account_key_json = {
        display_name    = "Service Account Key JSON"
        description     = "Service account key JSON for authenticating the STACKIT provider."
        type            = "FILE"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value   = "data:application/json;base64,${base64encode(module.backplane.service_account_key_json)}"
            secret_version = nonsensitive(sha256(module.backplane.service_account_key_json))
          }
        }
      }

      STACKIT_SERVICE_ACCOUNT_KEY_PATH = {
        display_name    = "STACKIT Credentials Path"
        description     = "Path to the STACKIT service account credentials file."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode("./service_account_key_json")
      }

      project_name = {
        display_name    = "Project Name"
        description     = "Name of the STACKIT project."
        type            = "STRING"
        assignment_type = "PROJECT_IDENTIFIER"
      }

      users = {
        display_name    = "Users"
        description     = "Project users with role assignments from meshStack."
        type            = "CODE"
        assignment_type = "USER_PERMISSIONS"
      }
    }

    outputs = {
      project_url = {
        display_name    = "Open Project"
        type            = "STRING"
        assignment_type = "RESOURCE_URL"
      }

      project_id = {
        display_name    = "Project ID"
        type            = "STRING"
        assignment_type = "PLATFORM_TENANT_ID"
      }

      container_id = {
        display_name    = "Container ID"
        type            = "STRING"
        assignment_type = "NONE"
      }

      project_name = {
        display_name    = "Project Name"
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

