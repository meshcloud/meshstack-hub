variable "stackit_project_id" {
  type        = string
  description = "STACKIT project ID where the backplane service account will be created."
}

variable "stackit_organization_id" {
  type        = string
  description = "STACKIT organization ID where the service account will be granted permissions."
}

variable "stackit_organization_member_role" {
  type        = string
  default     = "organization.viewer"
  description = "STACKIT organization role assigned best-effort to all meshStack project users before project role assignments are applied."
}

variable "stackit_organization_onboarding_enabled" {
  type        = bool
  default     = true
  description = "Whether the building block adds meshStack project users to the STACKIT organization (with `stackit_organization_member_role`) before applying project-level role assignments. Disable if organization membership is managed outside this building block."
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

variable "role_mapping" {
  type        = map(list(string))
  description = "Default mapping from meshStack roles to STACKIT project roles for the STACKIT Project building block. Values can be built-in STACKIT roles or custom STACKIT role names."

  default = {
    admin  = ["owner"]
    user   = ["editor"]
    reader = ["reader"]
  }
}

variable "stackit_project_labels" {
  type        = map(string)
  default     = {}
  description = "Labels applied to every STACKIT project created by this building block. Use the `networkArea` key to specify the STACKIT Network Area."
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

module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/project/backplane?ref=${var.hub.git_ref}"

  project_id                      = var.stackit_project_id
  organization_id                 = var.stackit_organization_id
  service_account_name            = coalesce(var.stackit_service_account_name, "mesh-project")
  organization_onboarding_enabled = var.stackit_organization_onboarding_enabled

  workload_identity_federation = {
    issuer = data.meshstack_integrations.integrations.workload_identity_federation.replicator.issuer
    subjects = [
      "${trimsuffix(data.meshstack_integrations.integrations.workload_identity_federation.replicator.subject, ":replicator")}:workspace.${var.meshstack.owning_workspace_identifier}.buildingblockdefinition.${meshstack_building_block_definition.this.metadata.uuid}"
    ]
  }
}

data "meshstack_integrations" "integrations" {}

output "building_block_definition" {
  description = "BBD is consumed in building block compositions."
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  }
}

resource "meshstack_platform" "stackit" {
  metadata = {
    name               = var.meshstack.platform_identifier
    owned_by_workspace = var.meshstack.owning_workspace_identifier
  }

  lifecycle {
    ignore_changes = [spec.availability]
  }

  spec = {
    display_name = "STACKIT Project"
    description  = "Create a STACKIT project with configurable role-based access control."
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
        platform_type_ref = { name = "STACKIT" }
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
    display_name              = "STACKIT Project"
    symbol                    = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/stackit/project/buildingblock/logo.png"
    description               = "Creates a new STACKIT project and manages user access permissions with configurable role-based access control."
    support_url               = "https://portal.stackit.cloud"
    target_type               = "TENANT_LEVEL"
    run_transparency          = true
    supported_platforms       = [{ name = "STACKIT" }]
    use_in_landing_zones_only = true
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
        pre_run_script = (var.stackit_organization_onboarding_enabled ? <<-SH
          exec python3 "./prerun.py" "$@"
          SH
        : null)
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
        description     = "Email of the STACKIT service account for WIF-based authentication."
        type            = "STRING"
        assignment_type = "STATIC"
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

      STACKIT_SERVICE_ACCOUNT_EMAIL = {
        display_name    = "STACKIT Service Account Email"
        description     = "Service account email used by the pre-run script for WIF token exchange."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(module.backplane.service_account_email)
      }

      STACKIT_ORGANIZATION_ID = {
        display_name    = "STACKIT Organization ID"
        description     = "STACKIT organization where meshStack project users are added best-effort before project role assignments are applied."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(var.stackit_organization_id)
      }

      STACKIT_ORGANIZATION_MEMBER_ROLE = {
        display_name    = "STACKIT Organization Member Role"
        description     = "STACKIT organization role assigned best-effort to all meshStack project users."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(var.stackit_organization_member_role)
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

      role_mapping = {
        display_name    = "Role Mapping"
        description     = "JSON object mapping meshStack roles to STACKIT project roles. Values can be built-in STACKIT roles or custom STACKIT role names."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.role_mapping))
      }

      labels = {
        display_name    = "Labels"
        description     = "Labels applied to the STACKIT project. Use the `networkArea` key to specify the STACKIT Network Area."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.stackit_project_labels))
      }
    }

    outputs = {
      project_url = {
        display_name    = "Open Project"
        type            = "STRING"
        assignment_type = "SIGN_IN_URL"
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
    stackit = {
      source  = "stackitcloud/stackit"
      version = ">= 0.98.0"
    }
  }
}

