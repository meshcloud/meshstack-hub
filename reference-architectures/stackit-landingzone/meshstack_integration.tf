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
    runner_ref = optional(object({
      kind = string
      uuid = string
    }))
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
  `git_ref`: Hub release reference. Set to a tag (e.g. 'v1.2.3') or branch or commit sha of the meshstack-hub repo.
  `bbd_draft`: If true, the definitions this landing zone registers (project starter kit, service account,
  federation, networks) are kept in draft mode. This definition is always a draft, so it stays in the owning
  workspace.
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

output "building_block_definition" {
  description = "BBD is consumed in building block compositions."
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = meshstack_building_block_definition.this.version_latest
  }
}

# meshPanel has no form widget for a map of free-form keys, so each tag map is a growable list of
# {key, values} entries; buildingblock/ folds them back into maps.
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

  approval_gates            = ["building_block_creation", "user_input_changes", "any_input_changes", "manual_triggers", "version_upgrade"]
  approval_policies_default = { for gate in local.approval_gates : gate => false }

  imports_definition_properties = {
    uuid                            = { type = "string", title = "uuid" }
    service_account_email           = { type = "string", title = "service_account_email" }
    federated_identity_provider_ids = { type = "array", title = "federated_identity_provider_ids", items = { type = "string" } }
  }

  imports_definition_schema = {
    type       = "object"
    required   = keys(local.imports_definition_properties)
    properties = local.imports_definition_properties
  }

  imports_container_schema = {
    type       = "object"
    required   = ["container_id"]
    properties = { container_id = { type = "string", title = "container_id" } }
  }

  tags_json_schema = {
    "$schema" = "http://json-schema.org/draft-07/schema#"
    type      = "object"
    required  = ["landingzone", "building_block", "project"]
    properties = {
      landingzone    = merge(local.tag_list_schema, { title = "Landing Zone Tags" })
      building_block = merge(local.tag_list_schema, { title = "Building Block Tags" })
      project        = merge(local.tag_list_schema, { title = "Project Tags" })
      project_owner_tag_key = {
        type        = "string"
        title       = "Project Owner Tag Key"
        description = "Tag on the created meshProjects that gets the creator's display name. Leave out to set none."
      }
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
    - **STACKIT root folder** *(optional)* – created at the organization root when a root folder
      name is given, and always in playground mode. It holds the landing-zone folder and the
      foundation project, so one organization can serve several meshStacks.
    - **STACKIT resourcemanager folder** – created in the root folder, or under the organization
      without one, and owned by the given owner email. New tenant projects are created inside this folder.
    - **STACKIT foundation project** – hosts the project-creation service account and other
      landing-zone core assets. It sits in the root folder, or in the landing-zone folder without one.
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

    **Playground Mode** is chosen when ordering and cannot be changed afterwards. Turned on, it
    deploys a throwaway platform: the platform identifier gets a random suffix, everything goes into a root folder named `playground-<platform identifier>`,
    and none of the folders nor the foundation project is protected against deletion, so the whole
    thing can be deleted again in one step.

    The suffix matters because a platform identifier is unique across the whole meshStack instance
    and becomes part of every landing zone name under it. A playground deployment would otherwise
    occupy the plain name for good. Such a platform and the building block definitions it registers
    are meant for the deploying workspace only — do not publish them to other workspaces.

    A platform that is actually used keeps **Playground Mode** off, the default. The identifier is then taken as given, and the folder and foundation project are guarded
    with `prevent_destroy`, so a deletion run fails rather than taking every tenant project with it.

    ## 🔑 Authentication

    You provide the STACKIT organization UUID, owner email, tags, default role mapping and the key of the deployment service account as inputs.
    The building block authenticates to STACKIT as the deployment service account, which needs `resource-manager.admin` on the organization.

    ## 📊 Shared responsibility

    | Responsibility | Platform Team | Application Team |
    |---|:---:|:---:|
    | Provide the deployment service account key, organization details, tags and role mapping | ✅ | ❌ |
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
    draft         = true
    runner_ref    = var.meshstack.runner_ref
    deletion_mode = "DELETE"

    permissions = [
      "INTEGRATION_LIST",
      "BUILDINGBLOCKDEFINITION_LIST",
      "BUILDINGBLOCKDEFINITION_SAVE",
      "BUILDINGBLOCKDEFINITION_DELETE",
      "BUILDINGBLOCK_LIST",
      "BUILDINGBLOCK_SAVE",
      "BUILDINGBLOCK_DELETE",
      "BUILDINGBLOCKRUNNER_LIST",
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
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      platform_identifier = {
        display_name                   = "Platform Identifier"
        description                    = "Identifier for the STACKIT sandbox platform created in meshStack (letters, digits and dashes only)."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[a-zA-Z0-9-]+$"
        validation_regex_error_message = "platform_identifier must only contain letters, digits, and dashes."
        display_order                  = 10
      }

      playground_mode = {
        display_name    = "Playground Mode"
        description     = "Throwaway deployment: the identifier gets a random suffix and nothing is protected against deletion. Do not publish such a platform or its definitions to other workspaces. Cannot be changed after the order."
        type            = "BOOLEAN"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(false)
        display_order   = 15
      }

      use_global_location = {
        display_name    = "Use Global Location"
        description     = "If true, use the existing global meshStack location instead of creating a dedicated location for this platform."
        type            = "BOOLEAN"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(true)
        display_order   = 20
      }

      stackit_org = {
        display_name                   = "STACKIT Organization UUID"
        description                    = "STACKIT organization UUID under which the landing-zone folder, foundation project and tenant projects are created."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
        validation_regex_error_message = "STACKIT Organization UUID must be a valid UUID."
        display_order                  = 30
      }

      root_folder_name = {
        display_name           = "Root Folder Name"
        description            = "Folder at the organization root for the landing-zone folder and the foundation project, when the organization serves more than one meshStack. Left out: no root folder."
        type                   = "STRING"
        assignment_type        = "USER_INPUT"
        is_optional            = true
        updateable_by_consumer = true
        display_order          = 35
      }

      stackit_service_account_key = {
        display_name           = "STACKIT Service Account Key"
        description            = "Full key JSON of the deployment service account, reused on every run. Needs `resource-manager.admin` on the organization, or organization owner to allow a different `stackit_owner_email`."
        type                   = "CODE"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        sensitive              = {}
        display_order          = 40
      }

      stackit_owner_email = {
        display_name    = "STACKIT Owner Email"
        description     = "Owner of the STACKIT folder, foundation project, and every tenant project. Applied at creation only. Must be the deployment service account's own email unless the deployment service account is an organization owner."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        display_order   = 50
      }

      topology = {
        display_name      = "Topology"
        description       = "Landing zones to deploy and offer application teams: `sandbox` and/or `hub&spoke` (the latter also provisions hub-and-spoke networking and reveals the Network form). The starterkit defaults to `sandbox` when selected, else `hub&spoke`."
        type              = "MULTI_SELECT"
        assignment_type   = "USER_INPUT"
        selectable_values = ["sandbox", "hub&spoke"]
        default_value     = jsonencode(["sandbox"])
        display_order     = 60
      }

      network = {
        display_name           = "Network (Hub-and-Spoke)"
        description            = "Hub-and-spoke address plan. Shown only when `hub&spoke` is selected; every field defaults to a sensible plan the operator can adjust."
        type                   = "JSON"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        condition              = "\"hub&spoke\" in input.topology"
        display_order          = 70

        # Hidden for the sandbox topology, so var.network falls back to null and networking stays off.
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

      role_mapping = {
        display_name           = "STACKIT Project Role Mapping"
        description            = "Maps each meshStack project role to the STACKIT project roles it grants. Values can be built-in STACKIT roles or custom STACKIT role names. organization_onboarding adds the users to the STACKIT organization first."
        type                   = "JSON"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        display_order          = 80

        json_schema = jsonencode({
          "$schema" = "http://json-schema.org/draft-07/schema#"
          type      = "object"
          required  = ["admin", "user", "reader"]
          properties = {
            admin  = { type = "array", title = "admin", items = { type = "string" }, default = ["owner"] }
            user   = { type = "array", title = "user", items = { type = "string" }, default = ["editor"] }
            reader = { type = "array", title = "reader", items = { type = "string" }, default = ["reader"] }
            organization_onboarding = {
              type        = "boolean"
              title       = "organization_onboarding"
              default     = true
              description = "Add meshStack project users to the STACKIT organization before the project roles are granted. Turn off if organization membership is managed outside this landing zone."
            }
          }
        })
      }

      tags = {
        display_name           = "Tags"
        description            = "Tags forwarded to the nested integrations. Build them in the form: add {key, values} entries for landing zones, building blocks, and the created meshProjects, plus the project owner tag key."
        type                   = "JSON"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        display_order          = 100

        json_schema = jsonencode(local.tags_json_schema)
      }

      starterkit_approval_policies = {
        display_name           = "Starterkit Approval Policies"
        description            = "Run triggers that need an operator's approval before a run of a project starterkit building block is applied."
        type                   = "JSON"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        default_value          = jsonencode(jsonencode(local.approval_policies_default))
        condition              = "!input.playground_mode"
        display_order          = 105

        json_schema = jsonencode({
          type                 = "object"
          additionalProperties = false
          required             = local.approval_gates
          properties           = { for gate, enabled in local.approval_policies_default : gate => { type = "boolean", title = gate, default = enabled } }
        })
      }

      imports = {
        display_name    = "Imports"
        description     = "Existing resources to take over when adopting a platform built before this architecture; see Adopting an Existing Platform in the README. Leave out to create everything."
        type            = "JSON"
        assignment_type = "USER_INPUT"
        is_optional     = true
        display_order   = 110

        json_schema = jsonencode({
          "$schema"            = "http://json-schema.org/draft-07/schema#"
          type                 = "object"
          additionalProperties = false
          properties = {
            folder             = merge(local.imports_container_schema, { title = "folder" })
            foundation_project = merge(local.imports_container_schema, { title = "foundation_project" })
            adopt_platform = {
              type        = "boolean"
              title       = "adopt_platform"
              description = "Adopt the existing meshPlatform, location and landing zones named by Platform Identifier."
            }
            project_definition = {
              type     = "object"
              title    = "project_definition"
              required = concat(keys(local.imports_definition_properties), ["service_account_name"])
              properties = merge(local.imports_definition_properties, {
                service_account_name = { type = "string", title = "service_account_name" }
              })
            }
            service_account_definition            = merge(local.imports_definition_schema, { title = "service_account_definition" })
            service_account_federation_definition = merge(local.imports_definition_schema, { title = "service_account_federation_definition" })
          }
        })
      }

      workspace = {
        display_name    = "Workspace Identifier"
        description     = "Workspace that will own the created platform, location and landing zones."
        type            = "STRING"
        assignment_type = "WORKSPACE_IDENTIFIER"
        display_order   = 900
      }

      hub = {
        display_name    = "Hub"
        description     = "HCL object with `git_ref` (meshstack-hub reference used to source the nested STACKIT integration modules) and `bbd_draft` (draft state of the definitions this landing zone registers)."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.hub))
        display_order   = 1000
      }
    }

    outputs = {
      lz_folder_container_id = {
        display_name    = "LZ Folder Container ID"
        type            = "STRING"
        assignment_type = "NONE"
      }

      root_container_id = {
        display_name    = "Root Container ID"
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
      version = ">= 0.27.0"
    }
  }
}
