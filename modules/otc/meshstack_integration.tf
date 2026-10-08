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
  description = "T Cloud Public domain (tenant) name, e.g. `OTC-EU-DE-00000000001000000000`, in which projects are created."
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
  description = "Name of the custom meshStack platform type the platform is registered as. It must already exist in the meshStack instance."
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

locals {
  console_login_url = coalesce(module.backplane.identity_provider_login_link, "https://console.otc.t-systems.com")

  # Federation inputs only exist with an identity provider; without one the buildingblock variable
  # defaults leave mapping off.
  federation_inputs = var.otc_identity_provider == null ? {} : {
    identity_provider_name = {
      display_name    = "Identity Provider"
      description     = "Federated identity provider whose mapping puts project users into the project groups."
      type            = "STRING"
      assignment_type = "STATIC"
      argument        = jsonencode(module.backplane.identity_provider_name)
    }

    identity_provider_email_attribute = {
      display_name    = "Identity Provider Email Attribute"
      description     = "SAML attribute or OIDC claim carrying the user's email address."
      type            = "STRING"
      assignment_type = "STATIC"
      argument        = jsonencode(module.backplane.identity_provider_email_attribute)
    }
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
        platform_type_ref = { name = var.otc_platform_type }
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
    description               = coalesce(var.bbd_description, "Creates a T Cloud Public project with one IAM group per meshStack role and maps federated project users into them.")
    support_url               = "https://console.otc.t-systems.com"
    target_type               = "TENANT_LEVEL"
    run_transparency          = true
    supported_platforms       = [{ name = var.otc_platform_type }]
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
        description     = "IAM endpoint the provider and the federation script authenticate against."
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

      OS_USERNAME = {
        display_name    = "OTC Username"
        description     = "IAM user the building block authenticates as, created by the backplane."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(module.backplane.user_name)
      }

      OS_PASSWORD = {
        display_name    = "OTC Password"
        description     = "Password of the backplane IAM user."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        sensitive = {
          argument = {
            secret_value   = module.backplane.password
            secret_version = nonsensitive(sha256(module.backplane.password))
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
      version = ">= 0.26.2"
    }
    opentelekomcloud = {
      source  = "opentelekomcloud/opentelekomcloud"
      version = ">= 1.37.0, < 2.0.0"
    }
  }
}
