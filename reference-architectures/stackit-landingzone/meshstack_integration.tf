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
  `git_ref`: Hub release reference. Set to a tag (e.g. 'v1.2.3') or branch or commit sha of the meshstack-hub repo.
  `bbd_draft`: If true, the building block definition version is kept in draft mode.
  EOT
}

variable "approval_policies" {
  type = object({
    building_block_creation = optional(bool, false)
    user_input_changes      = optional(bool, false)
    any_input_changes       = optional(bool, false)
    manual_triggers         = optional(bool, false)
    version_upgrade         = optional(bool, false)
  })
  nullable = false
  default = {
    building_block_creation = false
    user_input_changes      = false
    any_input_changes       = false
    manual_triggers         = false
    version_upgrade         = false
  }
  description = "Run triggers that need an operator's approval before a run of this architecture is applied. The defaults are the provider's own, and the provider asserts them whenever the definition sets no policies — so a gate switched on in meshPanel is turned off again by the next apply unless it is set here."
}

variable "starterkit_approval_policies" {
  type = object({
    building_block_creation = optional(bool, false)
    user_input_changes      = optional(bool, false)
    any_input_changes       = optional(bool, false)
    manual_triggers         = optional(bool, false)
    version_upgrade         = optional(bool, false)
  })
  nullable = false

  # Spelled out rather than left to the `optional()` defaults: this variable feeds a definition
  # input's `argument`, and a consumer that does not evaluate object-attribute defaulting would
  # see unset fields. See .agents/references/meshstack-integration.md.
  default = {
    building_block_creation = false
    user_input_changes      = false
    any_input_changes       = false
    manual_triggers         = false
    version_upgrade         = false
  }
  description = "The same, for the project starterkit definition this architecture registers. Set `building_block_creation` to have an operator approve every project an application team orders."
}

variable "playground_mode" {
  type     = bool
  nullable = false
  default  = true

  description = "Deploy a throwaway platform: the platform identifier gets a random suffix so it does not occupy a name for good, and the landing-zone folder and foundation project are left destroyable. Set to false for a platform that is actually used. Passed to the building block as a STATIC input, so whoever orders the architecture cannot choose. A playground platform and the building block definitions it registers are not meant to be published to other workspaces."
}

variable "default_tags" {
  type = object({
    landingzone           = optional(map(list(string)), {})
    building_block        = optional(map(list(string)), {})
    project               = optional(map(list(string)), {})
    project_owner_tag_key = optional(string, "")
  })
  nullable = false

  # Spelled out rather than left to the `optional()` defaults: this feeds an input's `json_schema`
  # default, and a consumer that does not evaluate object-attribute defaulting would see unset
  # fields. See .agents/references/meshstack-integration.md.
  default = {
    landingzone = {
      LandingZoneFamily = ["sandbox"]
      confidentiality   = ["internal", "public"]
      environment       = ["dev"]
    }
    building_block        = {}
    project               = {}
    project_owner_tag_key = "projectOwner"
  }

  description = "Starter values pre-filling the Tags form, as maps of tag key to values. Ships with an example set; override per foundation to match the instance's own tag schema. The operator can still edit, extend or clear them when ordering."
}

output "building_block_definition" {
  description = "BBD is consumed in building block compositions."
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  }
}

# The Tags input is a meshPanel form the operator fills from scratch: for each of the three tag maps
# they add as many {key, values} entries as they need — nothing is read from the instance's tag
# schema. A map of free-form keys has no form widget (meshPanel renders only declared properties), so
# each map is modelled as a growable array of entries; buildingblock/ folds them back into the
# map(list(string)) the nested integrations take.
locals {
  tag_list_schema = {
    type = "array"
    items = {
      type     = "object"
      required = ["key", "values"]
      properties = {
        key    = { type = "string", title = "Tag Key" }
        values = { type = "array", title = "Values", minItems = 1, items = { type = "string" } }
      }
    }
  }

  # The form's starter entries come from var.default_tags, so each foundation seeds keys matching its
  # own tag schema instead of anything hard-coded here. Each map is turned into the {key, values}
  # entry list the form (and the buildingblock variable) use.
  tags_default_entries = {
    for section, m in {
      landingzone    = var.default_tags.landingzone
      building_block = var.default_tags.building_block
      project        = var.default_tags.project
    } : section => [for tk, tv in m : { key = tk, values = tv }]
  }

  tags_json_schema = {
    "$schema" = "http://json-schema.org/draft-07/schema#"
    type      = "object"
    required  = ["landingzone", "building_block", "project", "project_owner_tag_key"]
    properties = {
      landingzone           = merge(local.tag_list_schema, { title = "Landing Zone Tags", default = local.tags_default_entries.landingzone })
      building_block        = merge(local.tag_list_schema, { title = "Building Block Tags", default = local.tags_default_entries.building_block })
      project               = merge(local.tag_list_schema, { title = "Project Tags", default = local.tags_default_entries.project })
      project_owner_tag_key = { type = "string", title = "Project Owner Tag Key", default = var.default_tags.project_owner_tag_key }
    }
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name      = coalesce(var.bbd_display_name, "STACKIT Landing Zone Reference Architecture")
    symbol            = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/reference-architectures/stackit-landingzone/buildingblock/logo.png"
    description       = coalesce(var.bbd_description, "Onboards a STACKIT sandbox platform into meshStack: a location, resourcemanager folder and the STACKIT Project platform with its default landing zone. Optionally layers on a hub-and-spoke network topology when a network config is provided.")
    support_url       = "https://portal.stackit.cloud"
    target_type       = "WORKSPACE_LEVEL"
    run_transparency  = true
    approval_policies = var.approval_policies

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
    The **STACKIT Landing Zone** building block bootstraps a complete STACKIT sandbox platform
    integration inside a meshStack workspace. Running it once turns a STACKIT organization into a
    sandbox-ready self-service platform: it registers a meshStack location, carves out a dedicated
    STACKIT resourcemanager folder for the workspace and wires up the **STACKIT Project** platform
    together with its default landing zone.

    Optionally, when you provide a **network** configuration, it additionally layers on a
    hub-and-spoke network topology: a shared network-area address plan (the hub) and a self-service
    routed-network building block (the spoke) that application teams can order inside their own
    STACKIT projects.

    ## 🎯 When to use it

    Use this building block when you:
    - want to onboard STACKIT in meshStack without manually creating locations, folders and project platform wiring.
    - need a reusable setup for sandbox environments where application teams can request STACKIT projects self-service.
    - (optionally) want all tenant projects to draw from a single, non-overlapping IPv4 address plan
      and let application teams self-service order routed subnets — enable this by providing the
      **network** configuration.

    ## 💡 Usage examples

    **Example 1: Enable a new STACKIT sandbox platform**
    A platform engineer runs this building block once for a workspace to bootstrap the STACKIT location, landing-zone folder
    and default `STACKIT Project` platform so teams can start requesting projects immediately.

    **Example 2: Bootstrap with hub-and-spoke networking**
    A platform engineer provides a **network** configuration (CIDR plan, prefix bounds). In addition
    to the sandbox platform, the building block provisions the hub network area with the chosen
    address plan, registers the **STACKIT Network** building block, and adds a dedicated `networked`
    STACKIT Project building block definition plus landing zone whose projects are placed in the hub
    network area. Application teams can then self-service order routed spoke networks inside their projects.

    A **network** configuration looks like this (sensible example values shown — adapt them to your
    own address plan):

    ```json
    {
      "hub_network_area_name": "hub",
      "hub_network_ranges": ["10.0.0.0/16"],
      "hub_transfer_network": "10.1.255.0/24",
      "hub_min_prefix_length": 24,
      "hub_max_prefix_length": 28,
      "hub_default_prefix_length": 28,
      "hub_default_nameservers": [],
      "tenant_network_min_prefix_length": 24,
      "tenant_network_max_prefix_length": 28
    }
    ```

    ## 📦 Resources created

    - **meshStack location** – named after the chosen platform identifier.
    - **STACKIT resourcemanager folder** – created under the configured organization and owned by the given owner email.
      New tenant projects are created inside this folder.
    - **STACKIT foundation project** – created directly under the organization to host the
      project-creation service account and other landing-zone core assets.
    - **STACKIT Project platform** – the `STACKIT Project` building block definition, platform and default landing zone,
      including the project-creation service account provisioned in the foundation project.
    - **STACKIT Service Account building block** – the `STACKIT Service Account` building block
      definition (`TENANT_LEVEL`), so application teams can self-service create a service account
      with project roles and optional workload identity federation inside their own projects.
    - **Hub network area + spoke network building block + networked project definition and landing
      zone** *(only when a network configuration is provided)* – the shared hub address plan, the
      self-service `STACKIT Network` building block, and a second `STACKIT Networked Project`
      building block definition plus landing zone that places projects into the hub network area.

    ## 🧪 Playground mode

    **Playground Mode** is fixed by whoever deployed this definition and cannot be chosen when
    ordering. It defaults to `true`, which deploys a throwaway platform: the platform identifier gets
    a random suffix, and neither the landing-zone folder nor the foundation project is protected
    against deletion, so the whole thing can be deleted again in one step.

    The suffix matters because a platform identifier is unique across the whole meshStack instance
    and becomes part of every landing zone name under it. A playground deployment would otherwise
    occupy the plain name for good. Such a platform and the building block definitions it registers
    are meant for the deploying workspace only — do not publish them to other workspaces.

    A platform that is actually used is deployed from a definition with **Playground Mode** set to
    `false`. The identifier is then taken as given, and the folder and foundation project are guarded
    with `prevent_destroy`, so a deletion run fails rather than taking every tenant project with it.

    ## 🔑 Authentication

    You provide the STACKIT organization UUID, owner email, tags, default role mapping and a service account key as inputs.
    The building block authenticates to STACKIT with the service account key, which needs `resource-manager.admin` on the organization.

    ## 📊 Shared responsibility

    | Responsibility | Platform Team | Application Team |
    |---|:---:|:---:|
    | Provide the STACKIT service account key, organization details, tags and role mapping | ✅ | ❌ |
    | Provision the location, folder and STACKIT Project platform | ✅ | ❌ |
    | Register the self-service `STACKIT Service Account` building block | ✅ | ❌ |
    | (Optional) Provide the network CIDR plan and provision the hub network area | ✅ | ❌ |
    | (Optional) Register the spoke `STACKIT Network` building block for self-service | ✅ | ❌ |
    | Request STACKIT projects through the landing zone | ❌ | ✅ |
    | Create service accounts inside their STACKIT projects | ❌ | ✅ |
    | (Optional) Order spoke networks inside their STACKIT projects | ❌ | ✅ |
    | Manage workloads inside the provisioned STACKIT projects | ❌ | ✅ |
    EOT
    ))
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"

    # Ephemeral API key permissions for meshStack resources created by this building block and its
    # nested foundation/network-area/network integrations (all part of the same Terraform run).
    permissions = [
      "INTEGRATION_LIST",
      "BUILDINGBLOCKDEFINITION_LIST",
      "BUILDINGBLOCKDEFINITION_SAVE",
      "BUILDINGBLOCKDEFINITION_DELETE",
      "BUILDINGBLOCK_LIST",
      "BUILDINGBLOCK_SAVE",
      "BUILDINGBLOCK_DELETE",
      "LANDINGZONE_LIST",
      "LANDINGZONE_SAVE",
      "LANDINGZONE_DELETE",
      "PLATFORMINSTANCE_LIST",
      "PLATFORMINSTANCE_SAVE",
      "PLATFORMINSTANCE_DELETE"
    ]

    implementation = {
      terraform = {
        terraform_version              = "1.12.5"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "reference-architectures/stackit-landingzone/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      # ── STACKIT authentication (service account key supplied by the operator) ──

      stackit_service_account_key = {
        display_name           = "STACKIT Service Account Key"
        description            = "Full key JSON of the deployment service account, reused on every run. Needs `resource-manager.admin` on the organization, or organization owner to allow a different `stackit_owner_email`."
        type                   = "CODE"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        sensitive              = {}
        display_order          = 60
      }

      hub = {
        display_name    = "Hub"
        description     = "HCL object with `git_ref` (meshstack-hub reference used to source the nested STACKIT integration modules) and `bbd_draft` (forwarded to those nested integrations' own building block definition draft state)."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.hub))
        display_order   = 120
      }

      # ── Platform configuration (set by the platform team) ──

      stackit_org = {
        display_name                   = "STACKIT Organization UUID"
        description                    = "STACKIT organization UUID under which the landing-zone folder, foundation project and tenant projects are created."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
        validation_regex_error_message = "STACKIT Organization UUID must be a valid UUID."
        display_order                  = 40
      }

      stackit_owner_email = {
        display_name    = "STACKIT Owner Email"
        description     = "Owner of the STACKIT folder, foundation project, and every tenant project. Applied at creation only. Must be the deployment account's own address unless that account is an organization owner."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        display_order   = 50
      }

      # Keep this description under roughly 200 characters. meshStack answers a longer one with
      # `500 InternalError` on the version update, not a 400 — the longest description any live
      # definition here carries is 206, and 387 fails.
      tags = {
        display_name           = "Tags"
        description            = "Tags forwarded to the nested integrations. Build them in the form: add {key, values} entries for landing zones, building blocks, and the created meshProjects, plus the project owner tag key."
        type                   = "JSON"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        display_order          = 80

        # meshStack decodes a JSON input into the buildingblock variable's declared object type (see
        # commit 991343f0), so `var.tags` stays the typed object and needs no jsondecode.
        json_schema = jsonencode(local.tags_json_schema)
      }

      role_mapping = {
        display_name           = "STACKIT Project Role Mapping"
        description            = "Maps each meshStack project role to the STACKIT project roles it grants. Values can be built-in STACKIT roles or custom STACKIT role names."
        type                   = "JSON"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        display_order          = 70

        # A JSON input decodes into var.role_mapping's map(list(string)); the three meshStack roles
        # are fixed keys, so the form is one field per role holding its STACKIT role list.
        json_schema = jsonencode({
          "$schema" = "http://json-schema.org/draft-07/schema#"
          type      = "object"
          required  = ["admin", "user", "reader"]
          properties = {
            admin  = { type = "array", title = "admin", items = { type = "string" }, default = ["owner"] }
            user   = { type = "array", title = "user", items = { type = "string" }, default = ["editor"] }
            reader = { type = "array", title = "reader", items = { type = "string" }, default = ["reader"] }
          }
        })
      }

      stackit_organization_onboarding_enabled = {
        display_name           = "STACKIT Organization Onboarding Enabled"
        description            = "If true, the nested STACKIT Project integration adds meshStack project users to the STACKIT organization before applying project-level role assignments."
        type                   = "BOOLEAN"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        default_value          = jsonencode(true)
        display_order          = 90
      }

      # ── Networking topology ──
      # `topology` is the SET of landing-zone labels the operator deploys and offers app teams. The
      # selectable values ARE the landing_zone_refs keys (`sandbox`, `hub&spoke`) — no translation —
      # so the buildingblock offers exactly the selected zones and picks one as the default. Selecting
      # `hub&spoke` also reveals the `network` form and provisions the networked landing zone.

      topology = {
        display_name      = "Topology"
        description       = "Landing zones to deploy and offer application teams: `sandbox` and/or `hub&spoke` (the latter also provisions hub-and-spoke networking and reveals the Network form). One selected zone becomes the ordering default."
        type              = "MULTI_SELECT"
        assignment_type   = "USER_INPUT"
        selectable_values = ["sandbox", "hub&spoke"]
        default_value     = jsonencode(["sandbox"])
        display_order     = 20
      }

      network = {
        display_name           = "Network (Hub-and-Spoke)"
        description            = "Hub-and-spoke address plan. Shown only when `hub&spoke` is selected; every field defaults to a sensible plan the operator can adjust."
        type                   = "JSON"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        condition              = "\"hub&spoke\" in input.topology"
        display_order          = 30

        # Decodes into var.network's object; hidden for the sandbox topology, so var.network falls
        # back to its null default and the buildingblock leaves networking off.
        json_schema = jsonencode({
          "$schema" = "http://json-schema.org/draft-07/schema#"
          type      = "object"
          properties = {
            hub_network_area_name            = { type = "string", title = "Hub Network Area Name", default = "hub-demo-test-1" }
            hub_network_ranges               = { type = "array", title = "Hub Network Ranges", items = { type = "string" }, default = ["10.0.0.0/16"] }
            hub_transfer_network             = { type = "string", title = "Hub Transfer Network", default = "10.1.255.0/24" }
            hub_min_prefix_length            = { type = "integer", title = "Hub Min Prefix Length", default = 24 }
            hub_max_prefix_length            = { type = "integer", title = "Hub Max Prefix Length", default = 28 }
            hub_default_prefix_length        = { type = "integer", title = "Hub Default Prefix Length", default = 28 }
            hub_default_nameservers          = { type = "array", title = "Hub Default Nameservers", items = { type = "string" }, default = [] }
            tenant_network_min_prefix_length = { type = "integer", title = "Tenant Network Min Prefix Length", default = 24 }
            tenant_network_max_prefix_length = { type = "integer", title = "Tenant Network Max Prefix Length", default = 28 }
          }
        })
      }

      # ── meshStack context ──

      workspace = {
        display_name    = "Workspace Identifier"
        description     = "Workspace that will own the created platform, location and landing zones."
        type            = "STRING"
        assignment_type = "WORKSPACE_IDENTIFIER"
        display_order   = 110
      }

      platform_identifier = {
        display_name                   = "Platform Identifier"
        description                    = "Identifier for the STACKIT sandbox platform created in meshStack (letters, digits and dashes only)."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[a-zA-Z0-9-]+$"
        validation_regex_error_message = "platform_identifier must only contain letters, digits, and dashes."
        display_order                  = 10
      }

      use_global_location = {
        display_name    = "Use Global Location"
        description     = "If true, use the existing global meshStack location instead of creating a dedicated location for this platform."
        type            = "BOOLEAN"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(false)
        display_order   = 100
      }

      starterkit_approval_policies = {
        display_name    = "Starterkit Approval Policies"
        description     = "HCL object of approval gates applied to the project starterkit definition this registers. Fixed by whoever deployed this definition."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.starterkit_approval_policies))
        display_order   = 130
      }

      playground_mode = {
        display_name    = "Playground Mode"
        description     = "Throwaway deployment: the identifier gets a random suffix and nothing is protected against deletion. Do not publish such a platform or its definitions to other workspaces. Set false for real use."
        type            = "BOOLEAN"
        assignment_type = "STATIC"
        argument        = jsonencode(var.playground_mode)
        display_order   = 140
      }
    }

    outputs = {
      lz_folder_container_id = {
        display_name    = "LZ Folder Container ID"
        type            = "STRING"
        assignment_type = "NONE"
      }

      foundation_project_id = {
        display_name    = "Foundation Project ID"
        type            = "STRING"
        assignment_type = "NONE"
      }

      foundation_project_url = {
        display_name    = "Open Foundation Project"
        type            = "STRING"
        assignment_type = "RESOURCE_URL"
      }

      # Exposed because the definition is created inside this building block's run, so there is no
      # module output to read it from. Not for ordering starterkit instances as code — the starterkit
      # deletes itself at the end of its run, so an as-code order creates another project on every
      # apply instead of converging. See the starterkit's readme.
      starterkit_bbd_version_uuid = {
        display_name    = "Starterkit BBD Version UUID"
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
      version = ">= 0.25.3"
    }
  }
}
