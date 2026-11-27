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

variable "ovh_endpoint" {
  type        = string
  default     = "ovh-eu"
  description = "OVHcloud API endpoint the building block calls, e.g. `ovh-eu`, `ovh-ca` or `ovh-us`."
}

variable "ovh_platform_type" {
  type        = string
  default     = "OVH"
  description = "Name of the custom meshStack platform type the platform is registered as: uppercase letters, digits and dashes."
}

variable "ovh_platform_type_display_name" {
  type        = string
  default     = "OVHcloud"
  description = "Display name of the platform type when `ovh_platform_type_create` is true. meshStack requires it to be unique across the instance, like the name."
}

variable "ovh_platform_type_create" {
  type        = bool
  default     = false
  description = "Create the platform type named `ovh_platform_type`. Leave false when it already exists in the meshStack instance; a platform type name is unique across the instance."
}

variable "ovh_application_key" {
  type        = string
  nullable    = false
  description = "Application key of the OVHcloud API application the building block authenticates as."
}

# An OVHcloud service account cannot order products, and Terraform cannot create consumer keys, so
# the building block takes a classic API credential created by hand. Restrict its consumer key to
# the paths the building block calls; see the building block's README.
variable "ovh_application_secret" {
  type        = string
  nullable    = false
  ephemeral   = true
  description = "Application secret of the OVHcloud API application."
}

variable "ovh_consumer_key" {
  type        = string
  nullable    = false
  ephemeral   = true
  description = "Consumer key the building block authenticates with."
}

variable "ovh_credentials_version" {
  type        = string
  nullable    = false
  default     = "1"
  description = "Increase to send a changed `ovh_application_secret` and `ovh_consumer_key` to meshStack."
}

variable "role_mapping" {
  type        = map(list(string))
  description = "Maps each meshStack project role to the OVHcloud IAM actions its members get on the Public Cloud project."

  default = {
    admin = ["publicCloudProject:apiovh:*"]
    user = [
      "publicCloudProject:apiovh:containerRegistry/*",
      "publicCloudProject:apiovh:dataProcessing/notebooks/*",
      "publicCloudProject:apiovh:dataProcessing/jobs/*",
      "publicCloudProject:apiovh:rancher/*",
      "publicCloudProject:apiovh:kube/*",
      "publicCloudProject:apiovh:instance/*",
      "publicCloudProject:apiovh:storage/*",
    ]
    reader = [
      "publicCloudProject:apiovh:containerRegistry/get",
      "publicCloudProject:apiovh:dataProcessing/notebooks/get",
      "publicCloudProject:apiovh:dataProcessing/jobs/get",
      "publicCloudProject:apiovh:rancher/get",
      "publicCloudProject:apiovh:kube/get",
      "publicCloudProject:apiovh:instance/get",
      "publicCloudProject:apiovh:storage/get",
    ]
  }
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    tags = optional(object({
      landingzone    = map(list(string))
      building_block = map(list(string))
    }), { landingzone = {}, building_block = {} })
    location_name       = optional(string, "global")
    platform_identifier = optional(string, "ovh")
    runner_ref = optional(object({
      kind = string
      uuid = string
    }))
    supported_platforms = optional(list(object({
      kind = optional(string)
      name = optional(string)
      uuid = optional(string)
    })))
  })
  description = "Shared meshStack context, see docs."
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

output "platform_type_name" {
  description = "Name of the platform type the platform is registered as, for definitions that support it."
  value       = local.platform_type_ref.name
}

output "platform_ref" {
  description = "Reference to the meshPlatform this integration creates, for compositions that create meshTenants on it."
  value       = meshstack_platform.this.ref
}

output "landingzone_ref" {
  description = "Reference to the default landing zone."
  value       = meshstack_landingzone.this.ref
}

locals {
  # Either the platform type this integration creates, or the existing one it names. The ref makes
  # the platform and the definition wait for a type created in the same apply.
  platform_type_ref = var.ovh_platform_type_create ? meshstack_platform_type.this.ref : { kind = "meshPlatformType", name = var.ovh_platform_type }
}

resource "meshstack_platform_type" "this" {
  lifecycle {
    enabled = var.ovh_platform_type_create
  }

  metadata = {
    name               = var.ovh_platform_type
    owned_by_workspace = var.meshstack.owning_workspace_identifier
  }

  spec = {
    display_name     = var.ovh_platform_type_display_name
    default_endpoint = "https://www.ovh.com/manager/"
    icon             = "data:image/png;base64,${filebase64("${path.module}/logo.png")}"
  }
}

resource "meshstack_platform" "this" {
  metadata = {
    name               = var.meshstack.platform_identifier
    owned_by_workspace = var.meshstack.owning_workspace_identifier
  }

  lifecycle {
    ignore_changes = [spec.availability]
  }

  spec = {
    display_name = "OVHcloud Public Cloud Project"
    description  = "Create an OVHcloud Public Cloud project with role-based access through OVHcloud IAM."
    endpoint     = "https://www.ovh.com/manager/"

    documentation_url = "https://hub.meshcloud.io/platforms/ovh"

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
        platform_type_ref = local.platform_type_ref
        metering = {
          processing = {
            compact_timelines_after_days = 30
            delete_raw_data_after_days   = 65
          }
        }
      }
    }
  }
}

# The project building block is deliberately not a mandatory building block of this landing zone:
# application teams add it to their tenant themselves.
resource "meshstack_landingzone" "this" {
  metadata = {
    name               = "${var.meshstack.platform_identifier}-default"
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags.landingzone
  }

  spec = {
    display_name                  = "OVHcloud Sandbox"
    description                   = "OVHcloud Public Cloud tenants. Add the OVHcloud Project building block to create the project."
    info_link                     = "https://hub.meshcloud.io/platforms/ovh"
    automate_deletion_approval    = true
    automate_deletion_replication = true

    platform_ref = meshstack_platform.this.ref

    platform_properties = {
      custom = {}
    }
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags.building_block
  }

  spec = {
    display_name        = coalesce(var.bbd_display_name, "OVHcloud Project")
    symbol              = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/ovh/project/buildingblock/logo.png"
    description         = coalesce(var.bbd_description, "Orders an OVHcloud Public Cloud project and grants meshStack project members access to it through OVHcloud IAM policies.")
    support_url         = "https://www.ovh.com/manager/"
    target_type         = "TENANT_LEVEL"
    run_transparency    = true
    supported_platforms = coalesce(var.meshstack.supported_platforms, [{ kind = null, name = local.platform_type_ref.name, uuid = null }])

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
    This building block orders the OVHcloud Public Cloud project behind your meshStack project and
    gives everyone on your meshStack project access to it, with the role they hold there.

    ## 🎯 When to use it

    Add it to your OVHcloud tenant right after creating the tenant: until you do, the tenant has no
    OVHcloud project. Manage access afterwards by adding or removing people on your meshStack
    project.

    ## 💡 Usage examples

    **Example 1: Start a new workload**
    You create a meshStack project with an OVHcloud tenant and add this building block to it. The
    project `<workspace>-<project>` appears in the OVHcloud Control Panel.

    **Example 2: Give a colleague read access**
    You add a colleague as reader on your meshStack project. After the next run they can see the
    project's resources but not change them.

    ## 🔑 Signing in

    Sign in to the OVHcloud Control Panel with your OVHcloud user, named like the part of your email
    before the `@`. The platform team creates these users; the building block summary lists project
    members who have none yet.

    ## 📊 Shared Responsibility

    | Responsibility | Platform Team | Application Team |
    |---|:---:|:---:|
    | Order the project and create its IAM policies | ✅ | ❌ |
    | Map meshStack roles to OVHcloud IAM actions | ✅ | ❌ |
    | Create OVHcloud users for project members | ✅ | ❌ |
    | Decide who is on the meshStack project, and with which role | ❌ | ✅ |
    | Build and run workloads inside the project, and their costs | ❌ | ✅ |
    EOT
    ))
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"
    runner_ref    = var.meshstack.runner_ref

    implementation = {
      terraform = {
        terraform_version              = "1.12.5"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/ovh/project/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      endpoint = {
        display_name    = "Endpoint"
        description     = "OVHcloud API endpoint."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.ovh_endpoint)
      }

      role_mapping = {
        display_name    = "Role Mapping"
        description     = "HCL object mapping meshStack roles to OVHcloud IAM actions."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.role_mapping))
      }

      workspace_identifier = {
        display_name    = "Workspace Identifier"
        description     = "meshStack workspace the project belongs to."
        type            = "STRING"
        assignment_type = "WORKSPACE_IDENTIFIER"
      }

      project_identifier = {
        display_name    = "Project Identifier"
        description     = "meshStack project the tenant belongs to."
        type            = "STRING"
        assignment_type = "PROJECT_IDENTIFIER"
      }

      users = {
        display_name    = "Users"
        description     = "Project users with role assignments from meshStack."
        type            = "CODE"
        assignment_type = "USER_PERMISSIONS"
      }

      OVH_APPLICATION_KEY = {
        display_name    = "OVHcloud Application Key"
        description     = "Application key of the OVHcloud API application the building block authenticates as."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(var.ovh_application_key)
      }

      OVH_APPLICATION_SECRET = {
        display_name    = "OVHcloud Application Secret"
        description     = "Application secret of the OVHcloud API application."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        sensitive = {
          argument = {
            secret_value   = var.ovh_application_secret
            secret_version = var.ovh_credentials_version
          }
        }
      }

      OVH_CONSUMER_KEY = {
        display_name    = "OVHcloud Consumer Key"
        description     = "Consumer key the building block authenticates with."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        sensitive = {
          argument = {
            secret_value   = var.ovh_consumer_key
            secret_version = var.ovh_credentials_version
          }
        }
      }
    }

    outputs = {
      project_url = {
        display_name    = "Open Control Panel"
        type            = "STRING"
        assignment_type = "SIGN_IN_URL"
      }

      project_id = {
        display_name    = "Project ID"
        type            = "STRING"
        assignment_type = "PLATFORM_TENANT_ID"
      }

      project_urn = {
        display_name    = "Project URN"
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
      version = ">= 0.26.4" # meshstack_platform_type
    }
  }
}
