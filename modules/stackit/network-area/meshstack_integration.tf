variable "stackit_organization_id" {
  type        = string
  description = "STACKIT organization ID under which network areas will be created."
}

variable "stackit_project_id" {
  type        = string
  description = "STACKIT project ID where the backplane service account will be created."
}

variable "stackit_service_account_name" {
  type        = string
  default     = null
  description = "Name of the backplane service account. Defaults to 'mesh-network-area'. Override when deploying multiple backplane instances in the same STACKIT project."
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    tags                        = optional(map(list(string)), {})
  })
  description = "Shared meshStack context."
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

data "meshstack_integrations" "integrations" {}

module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/network-area/backplane?ref=${var.hub.git_ref}"

  project_id           = var.stackit_project_id
  organization_id      = var.stackit_organization_id
  service_account_name = coalesce(var.stackit_service_account_name, "mesh-network-area")

  workload_identity_federation = {
    issuer = data.meshstack_integrations.integrations.workload_identity_federation.replicator.issuer
    subjects = [
      "${trimsuffix(data.meshstack_integrations.integrations.workload_identity_federation.replicator.subject, ":replicator")}:workspace.${var.meshstack.owning_workspace_identifier}.buildingblockdefinition.${meshstack_building_block_definition.this.metadata.uuid}"
    ]
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name        = "STACKIT Network Area"
    symbol              = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/stackit/network-area/buildingblock/logo.png"
    description         = "Creates a STACKIT network area with a configurable IPv4 address plan for network-segmented projects."
    support_url         = "https://portal.stackit.cloud"
    target_type         = "WORKSPACE_LEVEL"
    run_transparency    = true
    supported_platforms = [{ name = "STACKIT" }]
    readme = chomp(<<-EOT
      This building block provisions a **STACKIT network area** with a configurable IPv4
      address plan, so platform teams can organize STACKIT projects into network-segmented
      address spaces instead of relying on STACKIT's default flat networking.

      ## 🎯 When to use it

      Use this building block when you:
      - Need to establish a dedicated IPv4 address plan (ranges, transfer network, nameservers) for a group of STACKIT projects.
      - Want to segment STACKIT projects by environment or business unit into distinct network areas (e.g. "prod", "nonprod").
      - Are setting up network foundations before provisioning routed networks or connecting a firewall/VPN appliance.

      ## 💡 Usage examples

      **Example 1: Environment-segmented network areas**
      A platform team creates two network areas, "prod-na" and "nonprod-na", each with its
      own non-overlapping CIDR ranges, then tags each STACKIT Project landing zone with the
      matching `networkArea` name so new projects land in the right address space.

      **Example 2: Onboarding a new STACKIT organization**
      When onboarding a STACKIT organization to meshStack, a platform engineer instantiates
      this building block once to establish the organization's initial network area before
      any projects are created.

      ## 📊 Shared Responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Provision the network area and its IPv4 address plan | ✅ | ❌ |
      | Choose non-overlapping ranges across multiple network areas | ✅ | ❌ |
      | Tag STACKIT Project landing zones with the matching `networkArea` name | ✅ | ❌ |
      | Use projects within the assigned network area | ❌ | ✅ |
      EOT
    )
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"

    implementation = {
      terraform = {
        terraform_version              = "1.11.0"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/stackit/network-area/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      organization_id = {
        display_name    = "STACKIT Organization ID"
        description     = "STACKIT organization ID under which the network area will be created."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.stackit_organization_id)
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

      network_area_name = {
        display_name    = "Network Area Name"
        description     = "Name of the STACKIT network area."
        type            = "STRING"
        assignment_type = "USER_INPUT"
      }

      network_ranges = {
        display_name    = "Network Ranges"
        description     = "JSON list of IPv4 CIDR ranges available to projects within the network area, e.g. [\"10.0.0.0/16\"]."
        type            = "CODE"
        assignment_type = "USER_INPUT"
      }

      transfer_network = {
        display_name                   = "Transfer Network"
        description                    = "IPv4 CIDR range used as the transfer network between the network area and connected networks."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$"
        validation_regex_error_message = "Transfer network must be a valid IPv4 CIDR range, e.g. '10.255.255.0/24'."
      }

      min_prefix_length = {
        display_name    = "Minimum Prefix Length"
        description     = "Minimum prefix length allowed for networks created within the network area."
        type            = "INTEGER"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(24)
      }

      max_prefix_length = {
        display_name    = "Maximum Prefix Length"
        description     = "Maximum prefix length allowed for networks created within the network area."
        type            = "INTEGER"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(28)
      }

      default_prefix_length = {
        display_name    = "Default Prefix Length"
        description     = "Default prefix length used for networks created within the network area when none is specified."
        type            = "INTEGER"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(28)
      }

      default_nameservers = {
        display_name    = "Default Nameservers"
        description     = "JSON list of default IPv4 nameservers assigned to networks created within the network area."
        type            = "CODE"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(jsonencode(["1.0.0.1", "1.1.1.1"]))
      }
    }

    outputs = {
      network_area_id = {
        display_name    = "Network Area ID"
        type            = "STRING"
        assignment_type = "NONE"
      }

      network_area_name = {
        display_name    = "Network Area Name"
        type            = "STRING"
        assignment_type = "NONE"
      }

      network_ranges = {
        display_name    = "Network Ranges"
        type            = "CODE"
        assignment_type = "NONE"
      }

      transfer_network = {
        display_name    = "Transfer Network"
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
