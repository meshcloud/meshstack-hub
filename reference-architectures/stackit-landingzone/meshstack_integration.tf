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

variable "playground_mode" {
  type     = bool
  nullable = false
  default  = true

  description = "Deploy a throwaway platform: the platform identifier gets a random suffix so it does not occupy a name for good, and the landing-zone folder and foundation project are left destroyable. Set to false for a platform that is actually used. Passed to the building block as a STATIC input, so whoever orders the architecture cannot choose. A playground platform and the building block definitions it registers are not meant to be published to other workspaces."
}

output "building_block_definition" {
  description = "BBD is consumed in building block compositions."
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name     = "STACKIT Landing Zone Reference Architecture"
    symbol           = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/reference-architectures/stackit-landingzone/buildingblock/logo.png"
    description      = "Onboards a STACKIT sandbox platform into meshStack: a location, resourcemanager folder and the STACKIT Project platform with its default landing zone. Optionally layers on a hub-and-spoke network topology when a network config is provided."
    support_url      = "https://portal.stackit.cloud"
    target_type      = "WORKSPACE_LEVEL"
    run_transparency = true

    readme = chomp(<<-EOT
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
    | (Optional) Provide the network CIDR plan and provision the hub network area | ✅ | ❌ |
    | (Optional) Register the spoke `STACKIT Network` building block for self-service | ✅ | ❌ |
    | Request STACKIT projects through the landing zone | ❌ | ✅ |
    | (Optional) Order spoke networks inside their STACKIT projects | ❌ | ✅ |
    | Manage workloads inside the provisioned STACKIT projects | ❌ | ✅ |
    EOT
    )
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
      }

      hub = {
        display_name    = "Hub"
        description     = "HCL object with `git_ref` (meshstack-hub reference used to source the nested STACKIT integration modules) and `bbd_draft` (forwarded to those nested integrations' own building block definition draft state)."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.hub))
      }

      # ── Platform configuration (set by the platform team) ──

      stackit_org = {
        display_name                   = "STACKIT Organization UUID"
        description                    = "STACKIT organization UUID under which the landing-zone folder, foundation project and tenant projects are created."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
        validation_regex_error_message = "STACKIT Organization UUID must be a valid UUID."
      }

      stackit_owner_email = {
        display_name    = "STACKIT Owner Email"
        description     = "Owner of the STACKIT folder and foundation project, applied at creation only. Must be the deployment account's own address unless that account is an organization owner."
        type            = "STRING"
        assignment_type = "USER_INPUT"
      }

      # Keep this description under roughly 200 characters. meshStack answers a longer one with
      # `500 InternalError` on the version update, not a 400 — the longest description any live
      # definition here carries is 206, and 387 fails.
      tags = {
        display_name           = "Tags"
        description            = "HCL object of tag maps forwarded to the nested integrations: `landingzone`, `building_block`, and `project` for the meshProjects the starterkit creates. Set `project` where project tags are mandatory."
        type                   = "CODE"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true

        default_value = jsonencode(jsonencode({
          landingzone           = {}
          building_block        = {}
          project               = {}
          project_owner_tag_key = ""
        }))
      }

      role_mapping = {
        display_name           = "STACKIT Project Role Mapping"
        description            = "HCL object mapping meshStack roles from project users to STACKIT project roles. Values can be built-in STACKIT roles or custom STACKIT role names."
        type                   = "CODE"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true

        default_value = jsonencode(jsonencode({
          admin  = ["owner"]
          user   = ["editor"]
          reader = ["reader"]
        }))
      }

      stackit_organization_onboarding_enabled = {
        display_name           = "STACKIT Organization Onboarding Enabled"
        description            = "If true, the nested STACKIT Project integration adds meshStack project users to the STACKIT organization before applying project-level role assignments."
        type                   = "BOOLEAN"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        default_value          = jsonencode(true)
      }

      # ── Optional hub-and-spoke networking ──
      # Leave `network` as null to deploy only the sandbox landing zone. Provide an object to
      # additionally provision the hub network area, register the spoke network building block, and
      # create a networked landing zone.

      network = {
        display_name           = "Network (Hub-and-Spoke)"
        description            = <<-DESC
        Optional HCL object enabling hub-and-spoke networking. Leave as `null` to deploy only the
        sandbox landing zone. When set, all fields are optional
        DESC
        type                   = "CODE"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        default_value          = jsonencode(jsonencode(null))
      }

      # ── meshStack context ──

      workspace = {
        display_name    = "Workspace Identifier"
        description     = "Workspace that will own the created platform, location and landing zones."
        type            = "STRING"
        assignment_type = "WORKSPACE_IDENTIFIER"
      }

      platform_identifier = {
        display_name                   = "Platform Identifier"
        description                    = "Identifier for the STACKIT sandbox platform created in meshStack (letters, digits and dashes only)."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[a-zA-Z0-9-]+$"
        validation_regex_error_message = "platform_identifier must only contain letters, digits, and dashes."
      }

      use_global_location = {
        display_name    = "Use Global Location"
        description     = "If true, use the existing global meshStack location instead of creating a dedicated location for this platform."
        type            = "BOOLEAN"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(false)
      }

      playground_mode = {
        display_name    = "Playground Mode"
        description     = "Throwaway deployment: the identifier gets a random suffix and nothing is protected against deletion. Do not publish such a platform or its definitions to other workspaces. Set false for real use."
        type            = "BOOLEAN"
        assignment_type = "STATIC"
        argument        = jsonencode(var.playground_mode)
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
      version = ">= 0.24.0"
    }
  }
}
