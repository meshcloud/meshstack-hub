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

# STACKIT documents that a project's initial `members` must include "a user, and not a client or
# service account", but the API accepts both a service account and a plain mailbox as sole owner.
# We rely on that; the doc discrepancy is with STACKIT support as SSD-25050.
# We would rather create a project with no initial owner at all, but that needs a change in STACKIT.
variable "stackit_project_owner_email" {
  type        = string
  nullable    = false
  description = <<-EOT
  Email of the initial owner of every STACKIT project this platform creates. Use a platform-team
  address, not a personal one.

  STACKIT only applies this at project creation and ignores later changes, so it seeds initial IAM
  and nothing more. It is deliberately not the backplane service account: the account's access to
  created projects comes from its organization-scoped `resource-manager.admin` role, not from
  owning them.
  EOT
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
  description = "Additional labels applied to every STACKIT project created by this building block."
}

variable "stackit_network" {
  type = object({
    network_area_id = string
    definition_version_ref = object({
      uuid         = string
      content_hash = optional(string)
    })
    min_prefix_length = optional(number, 24)
    max_prefix_length = optional(number, 28)
  })
  default     = null
  description = <<-EOT
  Adds a second, `networked` landing zone. Its projects are placed in `network_area_id`, through the
  `networkArea` label, and order a routed network from `definition_version_ref`, usually
  `building_block_definition.version_ref` of `modules/stackit/network`. Null offers the `default`
  landing zone only.

  - Whether it is null must be known at plan time; its attributes may resolve during apply.
  - The network is ordered with the key of the application team's workspace. Publish the `STACKIT
    Network` definition and release the version once tenants of other workspaces use the networked
    landing zone. `content_hash` only matters for a draft version: a change re-runs the networks.
  - `min_prefix_length` and `max_prefix_length` bound the network size an application team may pick.
    Keep them within the bounds of the `STACKIT Network` definition.
  EOT
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
    tags = optional(object({
      landingzone    = map(list(string))
      building_block = map(list(string))
    }), { landingzone = {}, building_block = {} })
    location_name       = optional(string, "global")
    platform_identifier = optional(string, "stackit")
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

# Lookup specified runner for workload identity federation info. Null results in the default hosted runner.
module "runner" {
  source = "github.com/meshcloud/meshstack-hub//modules/meshstack/runner-identity?ref=${var.hub.git_ref}"

  cloud      = "azure"
  runner_ref = var.meshstack.runner_ref
}

module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/project/backplane?ref=${var.hub.git_ref}"

  project_id                      = var.stackit_project_id
  organization_id                 = var.stackit_organization_id
  service_account_name            = coalesce(var.stackit_service_account_name, "mesh-project")
  organization_onboarding_enabled = var.stackit_organization_onboarding_enabled

  # The runner offers no STACKIT token, so we use the one offered for Azure as a generic OIDC token. The federation trusts its issuer and audience.
  workload_identity_federation = {
    issuer   = module.runner.issuer
    audience = module.runner.audience
    subjects = [meshstack_building_block_definition.this.version_latest.workload_identity_federation.subject]
  }
}

output "building_block_definition" {
  description = "BBD is consumed in building block compositions."
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  }
}

output "service_account_email" {
  description = "Email of the backplane STACKIT service account that creates and manages tenant projects."
  value       = module.backplane.service_account_email
}

output "platform_ref" {
  description = "Reference to the meshPlatform this integration creates, for compositions that create meshTenants on it."
  value       = meshstack_platform.this.ref
}

output "landingzone_refs" {
  description = "References to the created landing zones, keyed `default`, and `networked` when `stackit_network` is set."
  value = {
    for key, lz in meshstack_landingzone.this : key => lz.ref
  }
}

locals {
  landing_zones = merge(
    {
      default = {
        display_name = "STACKIT Sandbox"
        description  = "STACKIT projects with STACKIT's default flat networking, and project roles mapped from meshStack project roles."
      }
    },
    var.stackit_network != null ? {
      networked = {
        display_name = "STACKIT Networked"
        description  = "STACKIT projects in the shared hub network area, with project roles mapped from meshStack project roles and a routed network drawn from the hub's address plan."
      }
    } : {}
  )

  # Built from the name rather than read from meshstack_landingzone.this, which depends on the definition.
  network_area_ids = var.stackit_network != null ? { "${var.meshstack.platform_identifier}-networked" = var.stackit_network.network_area_id } : {}

  # Pre-filled subnet size, so that a networked order needs no input.
  default_network_prefix_length = 25
}

moved {
  from = meshstack_platform.stackit
  to   = meshstack_platform.this
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
    display_name = "STACKIT Project"
    description  = "Create a STACKIT project with configurable role-based access control."
    endpoint     = "https://portal.stackit.cloud"

    documentation_url = "https://hub.meshcloud.io/reference-architectures/stackit-landingzone"

    location_ref = {
      name = var.meshstack.location_name
    }

    availability = {
      restriction              = "PRIVATE"
      publication_state        = "UNPUBLISHED"
      restricted_to_workspaces = [var.meshstack.owning_workspace_identifier]
      # Teams add STACKIT Project from the marketplace rather than order a bare tenant.
      hidden_in_marketplace = true
    }

    config = {
      custom = {
        platform_type_ref = { name = "STACKIT" }
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
  for_each = local.landing_zones

  metadata = {
    name               = "${var.meshstack.platform_identifier}-${each.key}"
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags.landingzone
  }

  spec = {
    display_name                  = each.value.display_name
    description                   = each.value.description
    info_link                     = "https://hub.meshcloud.io/reference-architectures/stackit-landingzone"
    automate_deletion_approval    = true
    automate_deletion_replication = true

    platform_ref = meshstack_platform.this.ref

    platform_properties = {
      custom = {}
    }
  }
}

resource "meshstack_building_block_definition" "this" {
  lifecycle {
    precondition {
      # The form pre-fills the default prefix length, so bounds that exclude it would fail every order
      # that leaves the field alone.
      condition     = var.stackit_network == null || (var.stackit_network.min_prefix_length <= local.default_network_prefix_length && local.default_network_prefix_length <= var.stackit_network.max_prefix_length)
      error_message = "The network prefix length bounds must include the default of /${local.default_network_prefix_length}."
    }
  }

  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags.building_block
  }

  spec = {
    display_name              = coalesce(var.bbd_display_name, "STACKIT Project")
    symbol                    = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/stackit/project/buildingblock/logo.png"
    description               = coalesce(var.bbd_description, "Creates a STACKIT project with your project members' roles. On a networked landing zone, the project is placed in the hub network area and gets a routed network.")
    support_url               = "https://portal.stackit.cloud"
    target_type               = "TENANT_LEVEL"
    run_transparency          = true
    use_in_landing_zones_only = false

    # Every STACKIT platform of a meshStack would otherwise offer every STACKIT Project definition.
    supported_platforms = coalesce(var.meshstack.supported_platforms, [
      for lz in meshstack_landingzone.this : { kind = lz.ref.kind, name = lz.ref.name, uuid = null }
    ])

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
    This building block creates the **STACKIT project** and gives your meshStack project members access to it. On a networked landing zone it also places the project in the hub network area and orders a routed **STACKIT Network** for it.


    Add it from the marketplace to a STACKIT tenant:
    1. Pick your meshStack project and its STACKIT tenant. No tenant yet? Create one there and pick its landing zone, which decides whether the project is networked.
    2. On a networked tenant, set the size of the network in the **Network** input. Other tenants don't show it.

    A tenant takes only one: the tenant is linked to the project it creates.

    ## 💡 Usage examples

    **Example 1: a sandbox project**
    A team uses a tenant on the sandbox landing zone. They get a STACKIT project with STACKIT's default flat networking, and their project members get the STACKIT roles mapped from their meshStack roles.

    **Example 2: a routed project**
    A team that needs private connectivity uses a tenant on the networked landing zone. Their project is placed in the hub network area and gets a routed `/${local.default_network_prefix_length}` network unless they pick another size. To resize it, change **Network** here; order more **STACKIT Network** building blocks for more networks.

    ## 📊 Shared Responsibility

    | Responsibility | Platform Team | Application Team |
    |---|:---:|:---:|
    | Provide the landing zones and the hub network area | ✅ | ❌ |
    | Create the STACKIT project and order its network | ✅ | ❌ |
    | Map meshStack roles to STACKIT project roles | ✅ | ❌ |
    | Pick the landing zone and the network size | ❌ | ✅ |
    | Manage project members in meshStack | ❌ | ✅ |
    | Manage resources inside the STACKIT project | ❌ | ✅ |
    EOT
    ))
  }

  version_spec = {
    draft                      = var.hub.bbd_draft
    deletion_mode              = "DELETE"
    runner_ref                 = module.runner.ref
    only_apply_once_per_tenant = true

    implementation = {
      terraform = {
        terraform_version              = "1.12.5"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/stackit/project/buildingblock"
        ref_name                       = var.hub.git_ref
        use_mesh_http_backend_fallback = true
        pre_run_script = (var.stackit_organization_onboarding_enabled ? <<-SH
          exec python3 "./prerun.py" "$@"
          SH
        : null)
      }
    }

    inputs = merge({
      parent_container_id = {
        display_name    = "Parent Container ID"
        description     = "Default parent container ID (organization or folder) where the project will be created."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.stackit_parent_container_id)
      }

      project_owner_email = {
        display_name    = "Project Owner Email"
        description     = "Email of the initial owner of the created project. Applied at creation only."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.stackit_project_owner_email)
      }

      organization_id = {
        display_name    = "STACKIT Organization ID"
        description     = "Organization where the building block looks up project users before it grants their roles, skipping those STACKIT does not know. Empty skips the lookup."
        type            = "STRING"
        assignment_type = "STATIC"
        # Only onboarding grants the service account `iam.member-admin`, which the lookup needs.
        argument = jsonencode(var.stackit_organization_onboarding_enabled ? var.stackit_organization_id : "")
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
        argument        = jsonencode(module.runner.token_path)
      }

      STACKIT_SERVICE_ACCOUNT_EMAIL = {
        display_name    = "STACKIT Service Account Email"
        description     = "Email of the STACKIT service account the provider and the pre-run script authenticate as via WIF."
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
        description     = "HCL object mapping meshStack roles to STACKIT project roles. Values can be built-in STACKIT roles or custom STACKIT role names."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.role_mapping))
      }

      labels = {
        display_name    = "Labels"
        description     = "Labels applied to the STACKIT project. The building block adds the `networkArea` label from Network Area IDs."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.stackit_project_labels))
      }

      tenant_uuid = {
        display_name    = "Tenant UUID"
        description     = "UUID of the meshStack tenant the project is created for. The network building block is ordered on it."
        type            = "STRING"
        assignment_type = "MESHSTACK_TENANT_UUID"
      }

      landing_zone = {
        display_name    = "Landing Zone"
        description     = "Identifier of the landing zone of the tenant the project is created for."
        type            = "STRING"
        assignment_type = "LANDING_ZONE_IDENTIFIER"
      }

      # Declared even with no networked landing zone: an empty map means no project gets a network.
      network_area_ids = {
        display_name    = "Network Area IDs"
        description     = "HCL object mapping each landing zone identifier with a network area to the STACKIT network area ID its projects are placed in."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(local.network_area_ids))
      }
      },
      # Declared unconditionally, these would be a field the application team fills in and nothing
      # reads, and a definition version nothing orders.
      var.stackit_network != null ? {
        network_definition_version_ref = {
          display_name    = "Network Definition Version"
          description     = "Version of the STACKIT Network definition the network of a networked project is ordered from."
          type            = "CODE"
          assignment_type = "STATIC"
          argument        = jsonencode(jsonencode(var.stackit_network.definition_version_ref))
        }

        network = {
          display_name           = "Network"
          description            = "Routed network ordered for the project as a STACKIT Network building block."
          type                   = "JSON"
          assignment_type        = "USER_INPUT"
          updateable_by_consumer = true
          # Optional, so that a tenant or building block created through the API needs no value: the
          # building block then falls back to its own defaults, the same as the form's.
          is_optional = true
          condition   = "input.landing_zone in ${jsonencode(keys(local.network_area_ids))}"

          json_schema = jsonencode({
            "$schema" = "http://json-schema.org/draft-07/schema#"
            type      = "object"
            properties = {
              prefix_length = {
                type        = "integer"
                title       = "Prefix Length"
                description = "Subnet size as an IPv4 prefix length."
                minimum     = var.stackit_network.min_prefix_length
                maximum     = var.stackit_network.max_prefix_length
                default     = local.default_network_prefix_length
              }
              ipv4_nameservers = {
                type        = "array"
                title       = "IPv4 Nameservers"
                description = "Leave empty to inherit the network area's default nameservers."
                items       = { type = "string" }
                default     = []
              }
            }
          })
        }
    } : {})

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

    # The building block orders the network building block of a networked project with the run's
    # ephemeral API key. Granted on every landing zone, because the meshStack provider needs
    # credentials to plan even where no network is ordered.
    permissions = [
      "BUILDINGBLOCK_LIST",
      "BUILDINGBLOCK_SAVE",
      "BUILDINGBLOCK_DELETE",
    ]
  }
}

# --- State address migrations (no resource recreation) ---
# Without these moves a deployed integration destroys the landing zone its tenants are assigned to,
# and the `STACKIT Project` definition that every tenant project building block instantiates.
moved {
  from = meshstack_landingzone.stackit_default
  to   = meshstack_landingzone.this["default"]
}
# The `networked` definition has no successor and is deleted, which fails while a tenant still uses it.
moved {
  from = meshstack_building_block_definition.this["default"]
  to   = meshstack_building_block_definition.this
}

terraform {
  required_version = ">= 1.12.0"

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.28.1"
    }
    stackit = {
      source  = "stackitcloud/stackit"
      version = ">= 0.98.0, < 1.0.0"
    }
  }
}

