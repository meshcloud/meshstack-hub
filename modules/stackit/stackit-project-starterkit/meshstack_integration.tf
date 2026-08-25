variable "platform_ref" {
  type = object({
    uuid = string
    kind = string
  })
  nullable    = false
  description = "Reference (by uuid) to the meshPlatform tenants are created on — e.g. the `platform_ref` output of `modules/stackit`. Required since the meshTenant v4 API references platforms by ref."
}

variable "landing_zone_refs" {
  type = map(object({
    name = string
    kind = string
  }))
  nullable    = false
  description = "Landing zones the application team can choose from, keyed by the label shown in the select — e.g. the `landingzone_refs` output of `modules/stackit`, relabelled. The definition builds its select from these keys and passes the whole map to the building block, which resolves the selected label against it."
}

variable "default_landing_zone" {
  type        = string
  default     = "sandbox"
  description = "Landing zone label pre-selected when the building block is ordered. Must be a key of `landing_zone_refs`."

  validation {
    condition     = contains(keys(var.landing_zone_refs), var.default_landing_zone)
    error_message = "default_landing_zone must be one of the keys of landing_zone_refs: ${join(", ", keys(var.landing_zone_refs))}."
  }
}

variable "network" {
  type = object({
    matching_landing_zones = set(string)
    bbd_version_ref        = object({ uuid = string })
    prefix_length_min      = number
    prefix_length_max      = number
  })
  default     = null
  description = "Spoke networks the starterkit can create. `matching_landing_zones` names the `landing_zone_refs` labels attached to a network area — only there is a network created, and only if the set is non-empty does the definition offer the `network` input at all. `bbd_version_ref` is the STACKIT Network definition version that creates it, and the prefix-length bounds are the ones that definition validates against. Null to offer no networks."

  validation {
    condition     = var.network == null || alltrue([for lz in var.network.matching_landing_zones : contains(keys(var.landing_zone_refs), lz)])
    error_message = "network.matching_landing_zones must only contain keys of landing_zone_refs: ${join(", ", keys(var.landing_zone_refs))}."
  }

  validation {
    condition     = var.network == null || var.network.prefix_length_max >= var.network.prefix_length_min
    error_message = "network.prefix_length_max must not be smaller than network.prefix_length_min."
  }

  validation {
    # The pre-filled value is hardcoded, so bounds that exclude it would fail every order that leaves
    # the field alone — which is the case the default exists for.
    condition     = var.network == null || (local.default_network_prefix_length >= var.network.prefix_length_min && local.default_network_prefix_length <= var.network.prefix_length_max)
    error_message = "The network default of /${local.default_network_prefix_length} is outside the allowed range. Widen the bounds or change the default."
  }
}

variable "add_random_name_suffix" {
  type        = bool
  default     = true
  description = "Append a five-character random suffix to the project name the application team enters."
}

variable "notification_subscribers" {
  type        = list(string)
  default     = []
  description = "meshStack usernames notified about runs of this building block definition."
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    tags = object({
      building_block        = map(list(string))
      project               = map(list(string))
      project_owner_tag_key = string
    })
  })
  nullable    = false
  description = "Shared meshStack context. `tags.building_block` goes on the definition's own metadata; `tags.project` and `tags.project_owner_tag_key` are passed through to the meshProjects the starterkit creates."
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
  `bbd_draft`: If true, the building block definition version is kept in draft mode.
  EOT
}

output "building_block_definition" {
  description = "BBD is consumed in building block compositions."
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  }
}

locals {
  # The STACKIT project name is the meshProject identifier, plus a five-character suffix. Dots and
  # underscores are excluded because a meshProject identifier does not accept them.
  name_regex = "^[a-zA-Z0-9-]{1,24}$"

  # Pre-filled subnet size. Hardcoded rather than a variable: the point of the default is that a
  # networked order needs no input, not that every deployment picks its own.
  default_network_prefix_length = 25

  # Null `network`, or an object naming no landing zone, both mean the same thing: no order can ever
  # get a spoke network, so the definition does not offer the input.
  network_enabled = length(try(var.network.matching_landing_zones, [])) > 0
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags.building_block
  }

  spec = {
    # `{{name}}` interpolates the `name` user input, so an ordered block is called after the project it
    # created rather than after the catalogue entry. The `(Starterkit)` suffix keeps it apart from the
    # `STACKIT Project` block the landing zone attaches to the tenant, which every starterkit order also
    # produces — without it the two read identically in a project's block list.
    display_name = "STACKIT Project (Starterkit)"
    symbol       = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/stackit/stackit-project-starterkit/buildingblock/logo.png"
    description  = "Creates a meshProject with a STACKIT project in the selected landing zone, and grants the creator Project Admin."
    # No `supported_platforms`: meshStack rejects a workspace-scoped definition that declares any, with
    # `400 A Workspace scoped Building Block Definition can not have supported platforms`. The field is
    # for tenant-level definitions, which are bound to a platform. Neither `ske/ske-starterkit` nor
    # `aks/starterkit` sets it, for the same reason.
    target_type              = "WORKSPACE_LEVEL"
    run_transparency         = true
    notification_subscribers = var.notification_subscribers

    readme = chomp(<<-EOT
    The **STACKIT Project Starterkit** gives your team a working STACKIT project through a single order. It creates a meshProject, places a STACKIT project tenant in the landing zone you select, and grants you the Project Admin role.

    ## 🎯 When to use it

    Order this building block when you:

    - Need a STACKIT project to build in and do not want to assemble the meshProject, the tenant and the access rights yourself.
    - Want the project governed from the start, with the tags and landing zone your platform team defined.

    ## 💡 Usage examples

    **Example 1: a project for a new service**
    A team starting a new service orders the starterkit with the name of the service and the `sandbox` landing zone. They get a meshProject, a STACKIT project inside it, and Project Admin on both.

    **Example 2: a routed project**
    A team that needs private connectivity picks a landing zone attached to a network area. Their STACKIT project is placed in that area and a routed subnet is created inside it in the same order — no second building block to request.

    ## What you get

    - A **meshProject** in your workspace, tagged as your platform team configured.
    - A **STACKIT project** in that meshProject, created by the landing zone's mandatory `STACKIT Project` building block.
    - A **routed network** inside the project, in landing zones attached to a network area, named after the project. The **Network** input controls its prefix length and nameservers; leaving it as it comes gives you a `/25`. Set it to `null` if you would rather have no network.
    - The **Project Admin** role for you, if you ordered this as a user rather than through an API key.

    You only see the **Network** input where at least one landing zone is attached to a network area. Picking a landing zone that is not attached to one gives you a project with no network, whatever the input says.

    One order creates one project. If you want separate development and production environments, order the starterkit twice.

    ## The starterkit removes itself when it is done

    Once everything above exists, this building block deletes itself, so you are not left with a block you cannot do anything further with. **Nothing it created is removed with it** — the meshProject, the STACKIT project and the network stay yours, and you manage them from then on. To get rid of them later, delete the meshProject.

    ## Shared Responsibilities

    | Responsibility | Platform Team | Application Team |
    | -------------- | ------------- | ---------------- |
    | Provide the STACKIT platform and its landing zones | ✅ | ❌ |
    | Define which project tags are set | ✅ | ❌ |
    | Create the meshProject and the STACKIT project | ✅ | ❌ |
    | Own the hub address plan the subnet is drawn from | ✅ | ❌ |
    | Choose the subnet size and nameservers | ❌ | ✅ |
    | Grant Project Admin to the creator | ✅ | ❌ |
    | Manage resources inside the STACKIT project | ❌ | ✅ |
    | Order further building blocks in the project | ❌ | ✅ |
    | Decide how many projects the team needs | ❌ | ✅ |
    EOT
    )
  }

  version_spec = {
    draft = var.hub.bbd_draft

    # PURGE, not DELETE, because the block deletes itself at the end of its own run — see
    # `terraform_data.self_purge` in the building block. Under PURGE meshStack runs no teardown, so
    # the meshProject, the meshTenant and the spoke network block all survive that delete and stay
    # with the application team. Under DELETE the self-delete would tear down everything the
    # starterkit just created.
    deletion_mode = "PURGE"

    implementation = {
      terraform = {
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/stackit/stackit-project-starterkit/buildingblock"
        ref_name                       = var.hub.git_ref
        terraform_version              = "1.12.5"
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = merge({
      # ── Filled in by meshStack per run ──

      creator = {
        assignment_type = "AUTHOR"
        type            = "CODE"
        display_name    = "Creator"
        description     = "Creator of the resources, who is granted the Project Admin role on the created project."
      }

      workspace_identifier = {
        assignment_type = "WORKSPACE_IDENTIFIER"
        type            = "STRING"
        display_name    = "Workspace Identifier"
        description     = "Workspace the starterkit provisions into."
      }

      # ── Chosen by the application team ──

      name = {
        assignment_type                = "USER_INPUT"
        type                           = "STRING"
        display_name                   = "Project Name"
        description                    = "Used for the created meshProject and its STACKIT project."
        value_validation_regex         = local.name_regex
        validation_regex_error_message = "Does not match ${local.name_regex} — letters, digits and dashes only, at most 24 characters."
      }

      landing_zone = {
        assignment_type   = "USER_INPUT"
        type              = "SINGLE_SELECT"
        display_name      = "Landing Zone"
        description       = "Landing zone the project is created in."
        selectable_values = keys(var.landing_zone_refs)
        default_value     = jsonencode(var.default_landing_zone)
      }

      # ── Set by the platform team ──

      platform_ref = {
        assignment_type = "STATIC"
        type            = "CODE"
        display_name    = "Platform Reference"
        description     = "HCL object referencing the meshPlatform the tenant is created on."
        # jsonencode twice is correct for structured inputs, see
        # https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block_definition#argument-1
        argument = jsonencode(jsonencode(var.platform_ref))
      }

      # The whole map, not just the selected entry: `landing_zone` above delivers only the label, and
      # the building block resolves it against this.
      landing_zone_refs = {
        assignment_type = "STATIC"
        type            = "CODE"
        display_name    = "Landing Zone References"
        description     = "HCL object mapping each select label to the meshLandingZone it refers to."
        # jsonencode twice is correct, see landing_zone_refs note above.
        argument = jsonencode(jsonencode(var.landing_zone_refs))
      }

      # Always declared, even with networking off: the building block reads
      # `matching_landing_zones` to decide whether the order gets a network, and an empty set is the
      # answer "never".
      network_static = {
        assignment_type = "STATIC"
        type            = "CODE"
        display_name    = "Network (Static)"
        description     = "HCL object naming the landing zones that get a spoke network, and the STACKIT Network definition version that creates it."
        argument = jsonencode(jsonencode({
          matching_landing_zones = local.network_enabled ? var.network.matching_landing_zones : []
          bbd_version_ref        = local.network_enabled ? var.network.bbd_version_ref : null
        }))
      }

      tags = {
        assignment_type = "STATIC"
        type            = "CODE"
        display_name    = "Tags"
        description     = "HCL object of tags applied to the created meshProject."
        # jsonencode twice is correct, see landing_zone_refs note above.
        argument = jsonencode(jsonencode(var.meshstack.tags))
      }

      add_random_name_suffix = {
        assignment_type = "STATIC"
        type            = "BOOLEAN"
        display_name    = "Add Random Name Suffix"
        description     = "Append a five-character random suffix to the project name."
        argument        = jsonencode(var.add_random_name_suffix)
      }
      },
      # Offered only where a network can actually be created. With no networked landing zone the
      # input would be a field the application team can fill in and that nothing ever reads.
      local.network_enabled ? {
        network = {
          assignment_type        = "USER_INPUT"
          type                   = "CODE"
          display_name           = "Network"
          description            = "HCL object for the spoke network created inside the project: `prefix_length` and `ipv4_nameservers`. The network is named after the project. Null for no network."
          updateable_by_consumer = true

          # Hand-written HCL rather than `jsonencode` of an object, because this is what the
          # application team is shown in the order form: a formatted block with one field per line is
          # editable, a single-line JSON string is not. The outer `jsonencode` wraps the document as a
          # string, the same shape `argument` uses for a CODE input.
          default_value = jsonencode(chomp(<<-NETWORK
          {
            # Subnet size as an IPv4 prefix length (${try(var.network.prefix_length_min, 24)}-${try(var.network.prefix_length_max, 28)}).
            prefix_length = ${local.default_network_prefix_length}

            # Leave empty to inherit the network area's default nameservers.
            ipv4_nameservers = []
          }
          NETWORK
          ))
        }
    } : {})

    outputs = {
      project_identifier = {
        assignment_type = "NONE"
        type            = "STRING"
        display_name    = "meshProject Identifier"
      }

      stackit_project_url = {
        assignment_type = "RESOURCE_URL"
        type            = "STRING"
        display_name    = "Open STACKIT Project"
      }

      network_cidr = {
        assignment_type = "NONE"
        type            = "STRING"
        display_name    = "Network CIDR"
      }

      summary = {
        assignment_type = "SUMMARY"
        type            = "STRING"
        display_name    = "Summary"
      }
    }

    # BUILDINGBLOCK_* is for the spoke network block this orders inside the tenant. The STACKIT
    # Project block is not ours — the landing zone attaches that one.
    permissions = [
      "BUILDINGBLOCK_LIST",
      "BUILDINGBLOCK_SAVE",
      "BUILDINGBLOCK_DELETE",
      "PROJECT_LIST",
      "PROJECT_SAVE",
      "PROJECT_DELETE",
      "PROJECTPRINCIPALROLE_LIST",
      "PROJECTPRINCIPALROLE_SAVE",
      "PROJECTPRINCIPALROLE_DELETE",
      "TENANT_LIST",
      "TENANT_SAVE",
      "TENANT_DELETE",
    ]
  }
}

terraform {
  required_version = ">= 1.12.0"

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.24.0"
    }
  }
}
