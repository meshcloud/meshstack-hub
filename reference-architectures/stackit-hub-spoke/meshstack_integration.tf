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
    display_name     = "STACKIT Hub and Spoke Network"
    symbol           = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/reference-architectures/stackit-hub-spoke/buildingblock/logo.png"
    description      = "Bootstraps a STACKIT sandbox platform together with a hub-and-spoke network topology: a shared network-area address plan and a self-service routed-network building block for application teams."
    support_url      = "https://portal.stackit.cloud"
    target_type      = "WORKSPACE_LEVEL"
    run_transparency = true

    readme = chomp(<<-EOT
    Bootstraps a STACKIT sandbox platform together with a hub-and-spoke network topology: it
    provisions a shared network-area address plan (the hub) and registers a self-service
    routed-network building block (the spoke) that application teams can order inside their
    own STACKIT projects.

    ## 🎯 When to use it

    Use this building block when you:
    - want a STACKIT platform where all tenant projects draw from a single, non-overlapping
      IPv4 address plan instead of STACKIT's default flat networking.
    - need application teams to self-service order routed subnets inside their projects
      without manually coordinating CIDR ranges with the platform team.
    - are bootstrapping a new STACKIT organization and want the network foundation (hub)
      provisioned in the same step as the platform itself.

    ## 💡 Usage examples

    **Example 1: Bootstrap a new STACKIT sandbox with hub-and-spoke networking**
    A platform engineer orders this building block once for a workspace. It creates the STACKIT
    platform, provisions the hub network area with a chosen CIDR plan, and registers the
    **STACKIT Network** building block so application teams can request spokes.

    **Example 2: Order a spoke network**
    Once the platform is bootstrapped, an application team orders the **STACKIT Network**
    building block inside their own STACKIT project to get a routed subnet drawn from the hub's
    address plan — no manual IPAM coordination needed.

    ## 📊 Shared Responsibility

    | Responsibility | Platform Team | Application Team |
    |---|:---:|:---:|
    | Provision the STACKIT platform, hub network area, and its address plan | ✅ | ❌ |
    | Choose non-overlapping CIDR ranges for the hub | ✅ | ❌ |
    | Register the spoke `STACKIT Network` building block for self-service | ✅ | ❌ |
    | Order spoke networks inside their STACKIT projects | ❌ | ✅ |
    | Use the assigned subnet for their workloads | ❌ | ✅ |
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
        terraform_version              = "1.12.0"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "reference-architectures/stackit-hub-spoke/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      # ── STACKIT authentication (service account key supplied by the operator) ──

      stackit_service_account_key = {
        display_name           = "STACKIT Service Account Key"
        description            = "STACKIT service account key JSON with `resource-manager.admin` on the organization. Paste the full JSON as a secret input."
        type                   = "CODE"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        sensitive              = {}
      }

      hub = {
        display_name    = "Hub"
        description     = "JSON object with `git_ref` (meshstack-hub reference used to source the nested foundation, network-area, and network integration modules) and `bbd_draft` (forwarded to those nested integrations' own building block definition draft state)."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.hub))
      }

      # ── Platform configuration (set by the platform team) ──

      stackit_org = {
        display_name                   = "STACKIT Organization UUID"
        description                    = "STACKIT organization UUID under which the landing-zone folder, backplane project and tenant projects are created."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
        validation_regex_error_message = "STACKIT Organization UUID must be a valid UUID."
      }

      stackit_owner_email = {
        display_name    = "STACKIT Owner Email"
        description     = "Owner email assigned to the STACKIT resourcemanager folder and backplane project."
        type            = "STRING"
        assignment_type = "USER_INPUT"
      }

      tags = {
        display_name           = "Tags"
        description            = "JSON object with `landingzone` and `building_block` tag maps forwarded to the nested foundation, network-area, and network integrations."
        type                   = "CODE"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true

        default_value = jsonencode(jsonencode({
          landingzone    = {}
          building_block = {}
        }))
      }

      role_mapping = {
        display_name           = "STACKIT Project Role Mapping"
        description            = "JSON object mapping meshStack roles from project users to STACKIT project roles. Values can be built-in STACKIT roles or custom STACKIT role names."
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

      network_area_tag_name = {
        display_name           = "Network Area Tag Name"
        description            = "Name of the meshStack landing zone tag whose value is the hub network area's ID. Forwarded to the foundation's nested STACKIT Project integration and set on the `networked` landing zone created by this building block."
        type                   = "STRING"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        default_value          = jsonencode("StackitNetworkArea")
      }

      # ── Hub network area configuration ──

      hub_network_area_name = {
        display_name    = "Hub Network Area Name"
        description     = "Name of the hub STACKIT network area instance."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("hub")
      }

      hub_network_ranges = {
        display_name    = "Hub Network Ranges"
        description     = "JSON list of IPv4 CIDR ranges available to projects within the hub network area, e.g. [\"10.0.0.0/16\"]."
        type            = "CODE"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(jsonencode(["10.0.0.0/16"]))
      }

      hub_transfer_network = {
        display_name                   = "Hub Transfer Network"
        description                    = "IPv4 CIDR range used as the transfer network between the hub network area and connected networks. Must not overlap with the Hub Network Ranges."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        default_value                  = jsonencode("10.1.255.0/24")
        value_validation_regex         = "^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$"
        validation_regex_error_message = "Transfer network must be a valid IPv4 CIDR range, e.g. '10.1.255.0/24'."
      }

      hub_min_prefix_length = {
        display_name    = "Hub Minimum Prefix Length"
        description     = "Minimum prefix length allowed for networks created within the hub network area."
        type            = "INTEGER"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(24)
      }

      hub_max_prefix_length = {
        display_name    = "Hub Maximum Prefix Length"
        description     = "Maximum prefix length allowed for networks created within the hub network area."
        type            = "INTEGER"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(28)
      }

      hub_default_prefix_length = {
        display_name    = "Hub Default Prefix Length"
        description     = "Default prefix length used for networks created within the hub network area when none is specified."
        type            = "INTEGER"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(28)
      }

      hub_default_nameservers = {
        display_name    = "Hub Default Nameservers"
        description     = "JSON list of default IPv4 nameservers assigned to networks created within the hub network area."
        type            = "CODE"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(jsonencode([]))
      }

      # ── Spoke network configuration (bounds offered to application teams) ──

      tenant_network_min_prefix_length = {
        display_name    = "Tenant Network Minimum Prefix Length"
        description     = "Minimum allowed IPv4 prefix length for the spoke network BBD's prefix length input, offered to application teams ordering spoke networks."
        type            = "INTEGER"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(24)
      }

      tenant_network_max_prefix_length = {
        display_name    = "Tenant Network Maximum Prefix Length"
        description     = "Maximum allowed IPv4 prefix length for the spoke network BBD's prefix length input, offered to application teams ordering spoke networks."
        type            = "INTEGER"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(28)
      }

      # ── meshStack context ──

      workspace = {
        display_name    = "Workspace Identifier"
        description     = "Workspace that will own the created platform, location, landing zones, and the hub network-area instance."
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
    }

    outputs = {
      lz_folder_container_id = {
        display_name    = "LZ Folder Container ID"
        type            = "STRING"
        assignment_type = "NONE"
      }

      backplane_project_id = {
        display_name    = "Backplane Project ID"
        type            = "STRING"
        assignment_type = "NONE"
      }

      backplane_project_url = {
        display_name    = "Open Backplane Project"
        type            = "STRING"
        assignment_type = "RESOURCE_URL"
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
