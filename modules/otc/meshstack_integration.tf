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

variable "otc_domain_name" {
  type        = string
  description = "T Cloud Public domain (account) name, e.g. `OTC-EU-DE-00000000001000000000`, in which projects are created."
}

variable "otc_region" {
  type        = string
  default     = "eu-de"
  description = "T Cloud Public region projects are created in."
}

variable "otc_auth_url" {
  type        = string
  default     = "https://iam.eu-de.otc.t-systems.com/v3"
  description = "IAM endpoint the building block authenticates against."
}

variable "otc_platform_type" {
  type        = string
  default     = "OTC"
  description = "Name of the custom meshStack platform type the platform is registered as: uppercase letters, digits and dashes."
}

variable "otc_platform_type_create" {
  type        = bool
  default     = false
  description = "Create the platform type named `otc_platform_type`. Leave false when it already exists in the meshStack instance; a platform type name is unique across the instance."
}

variable "otc_backplane_user_name" {
  type        = string
  default     = null
  description = "Name of the IAM user the project building block authenticates as. Defaults to 'mesh-project'. Override when deploying several integrations into one domain."
}

variable "otc_identity_provider" {
  type = object({
    name     = string
    protocol = string
    metadata = optional(string)
    oidc = optional(object({
      provider_url           = string
      client_id              = string
      signing_key            = string
      authorization_endpoint = optional(string)
      scopes                 = optional(list(string), ["openid"])
    }))
    email_attribute = optional(string, "email")
  })
  default     = null
  description = "Customer identity provider federated into the domain, so meshStack project users sign in as virtual users. See the backplane's `identity_provider` variable. Null creates projects and groups without mapping users into them."
}

variable "role_mapping" {
  type        = map(list(string))
  description = "Maps each meshStack project role to the T Cloud Public system roles (by role `name`) its project group gets."

  default = {
    admin  = ["te_admin"]
    user   = ["te_admin"]
    reader = ["readonly"]
  }
}

variable "building_block_runner_uuid" {
  type        = string
  default     = null
  description = "Runs this building block on the given meshStack building block runner instead of the shared one meshStack hosts."
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    tags = optional(object({
      landingzone    = map(list(string))
      building_block = map(list(string))
    }), { landingzone = {}, building_block = {} })
    location_name       = optional(string, "global")
    platform_identifier = optional(string, "otc")
  })
  description = <<-EOT
  Shared meshStack context.
  `owning_workspace_identifier`: Identifier of the meshStack workspace that owns the managed resources.
  `tags`: Optional tags propagated to building block definition and landing zone metadata.
  `location_name`: meshStack location name for the platform. Defaults to "global".
  `platform_identifier`: Identifier for the platform in meshStack. Defaults to "otc".
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
  source = "github.com/meshcloud/meshstack-hub//modules/otc/project/backplane?ref=${var.hub.git_ref}"

  user_name         = coalesce(var.otc_backplane_user_name, "mesh-project")
  identity_provider = var.otc_identity_provider
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

output "identity_provider_login_link" {
  description = "Console login link for federated users, or null without federation."
  value       = module.backplane.identity_provider_login_link
}

output "federation" {
  description = "What the federation mapping building block needs to rebuild the identity provider's mapping, or null without federation."
  value = var.otc_identity_provider == null ? null : {
    mapping_bucket         = module.backplane.mapping_bucket
    identity_provider_name = module.backplane.identity_provider_name
    email_attribute        = module.backplane.identity_provider_email_attribute
  }
}

output "backplane_credentials" {
  description = "Access key of the backplane IAM user, for compositions that run further building blocks as it."
  sensitive   = true
  value = {
    access_key = module.backplane.access_key
    secret_key = module.backplane.secret_key
  }
}

locals {
  # Either the platform type this integration creates, or the existing one it names. The ref makes
  # the platform and the definition wait for a type created in the same apply.
  platform_type_ref = var.otc_platform_type_create ? meshstack_platform_type.this.ref : { kind = "meshPlatformType", name = var.otc_platform_type }

  console_login_url = coalesce(module.backplane.identity_provider_login_link, "https://console.otc.t-systems.com")

  # Without federation there is no bucket, and the buildingblock variable's null default leaves
  # membership unrecorded.
  federation_inputs = var.otc_identity_provider == null ? {} : {
    mapping_bucket = {
      display_name    = "Mapping Bucket"
      description     = "OBS bucket the project records its group membership in."
      type            = "STRING"
      assignment_type = "STATIC"
      argument        = jsonencode(module.backplane.mapping_bucket)
    }
  }
}

resource "meshstack_platform_type" "this" {
  lifecycle {
    enabled = var.otc_platform_type_create
  }

  metadata = {
    name               = var.otc_platform_type
    owned_by_workspace = var.meshstack.owning_workspace_identifier
  }

  spec = {
    display_name     = "T Cloud Public"
    default_endpoint = "https://console.otc.t-systems.com"
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
    display_name = "T Cloud Public Project"
    description  = "Create a T Cloud Public (Open Telekom Cloud) project with role-based access through your company identity provider."
    endpoint     = "https://console.otc.t-systems.com"

    documentation_url = "https://hub.meshcloud.io/reference-architectures/otc-landingzone"

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

resource "meshstack_landingzone" "this" {
  metadata = {
    name               = "${var.meshstack.platform_identifier}-default"
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags.landingzone
  }

  spec = {
    display_name                  = "T Cloud Public Sandbox"
    description                   = "Creates a T Cloud Public project in ${var.otc_region} with project roles mapped from meshStack project roles."
    info_link                     = "https://hub.meshcloud.io/reference-architectures/otc-landingzone"
    automate_deletion_approval    = true
    automate_deletion_replication = true

    platform_ref = meshstack_platform.this.ref

    platform_properties = {
      custom = {}
    }

    mandatory_building_block_refs = [meshstack_building_block_definition.this.ref]
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags.building_block
  }

  spec = {
    display_name              = coalesce(var.bbd_display_name, "T Cloud Public Project")
    symbol                    = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/otc/project/buildingblock/logo.png"
    description               = coalesce(var.bbd_description, "Creates a T Cloud Public project with one IAM group per meshStack role and records which federated users belong in them.")
    support_url               = "https://console.otc.t-systems.com"
    target_type               = "TENANT_LEVEL"
    run_transparency          = true
    supported_platforms       = [{ name = local.platform_type_ref.name }]
    use_in_landing_zones_only = true

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
    This building block creates the T Cloud Public (Open Telekom Cloud) project behind your meshStack
    project and gives everyone on your meshStack project access to it, with the role they hold there.

    ## 🎯 When to use it

    It runs automatically for every meshStack project created in a T Cloud Public landing zone — you
    do not order it yourself. Manage access by adding or removing people on your meshStack project.

    ## 💡 Usage examples

    **Example 1: Start a new workload**
    You create a meshStack project in the T Cloud Public landing zone. The project
    `eu-de_<your-project>` appears in the T Cloud Public console, and you sign in with your company
    account.

    **Example 2: Give a colleague read access**
    You add a colleague as reader on your meshStack project. From their next sign-in they can see the
    project's resources but not change them.

    ## 🔑 Signing in

    Sign in with your company account at the link in the building block summary, then switch to your
    project in the console's project selector. Role changes take effect at your next sign-in.

    ## 📊 Shared Responsibility

    | Responsibility | Platform Team | Application Team |
    |---|:---:|:---:|
    | Create the project and its IAM groups | ✅ | ❌ |
    | Map meshStack roles to T Cloud Public roles | ✅ | ❌ |
    | Federate the company identity provider | ✅ | ❌ |
    | Decide who is on the meshStack project, and with which role | ❌ | ✅ |
    | Build and run workloads inside the project | ❌ | ✅ |
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
        repository_path                = "modules/otc/project/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = merge(local.federation_inputs, {
      region = {
        display_name    = "Region"
        description     = "T Cloud Public region the project is created in."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.otc_region)
      }

      project_name = {
        display_name    = "Project Name"
        description     = "Name of the project, without the region prefix."
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
        description     = "HCL object mapping meshStack roles to T Cloud Public system role names."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.role_mapping))
      }

      console_login_url = {
        display_name    = "Console Login URL"
        description     = "Where project users sign in."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(local.console_login_url)
      }

      OS_AUTH_URL = {
        display_name    = "OTC Auth URL"
        description     = "IAM endpoint the provider authenticates against."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(var.otc_auth_url)
      }

      OS_DOMAIN_NAME = {
        display_name    = "OTC Domain Name"
        description     = "T Cloud Public domain the building block user belongs to and acts in."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(var.otc_domain_name)
      }

      OS_ACCESS_KEY = {
        display_name    = "OTC Access Key"
        description     = "Access key of the backplane IAM user the building block authenticates as."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        sensitive = {
          argument = {
            secret_value   = module.backplane.access_key
            secret_version = nonsensitive(sha256(module.backplane.access_key))
          }
        }
      }

      OS_SECRET_KEY = {
        display_name    = "OTC Secret Key"
        description     = "Secret key of the backplane IAM user."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        sensitive = {
          argument = {
            secret_value   = module.backplane.secret_key
            secret_version = nonsensitive(sha256(module.backplane.secret_key))
          }
        }
      }
    })

    outputs = {
      project_url = {
        display_name    = "Open Console"
        type            = "STRING"
        assignment_type = "SIGN_IN_URL"
      }

      project_id = {
        display_name    = "Project ID"
        type            = "STRING"
        assignment_type = "PLATFORM_TENANT_ID"
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
      version = ">= 0.26.4" # meshstack_platform_type
    }
    opentelekomcloud = {
      source  = "opentelekomcloud/opentelekomcloud"
      version = ">= 1.37.0, < 2.0.0"
    }
  }
}
