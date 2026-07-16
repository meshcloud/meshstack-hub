variable "stackit_organization_id" {
  type        = string
  description = "STACKIT organization ID under which target projects live."
}

variable "stackit_project_id" {
  type        = string
  description = "STACKIT project ID where the backplane service account will be created."
}

variable "stackit_service_account_name" {
  type        = string
  default     = null
  description = "Name of the backplane service account. Defaults to 'mesh-network'. Override when deploying multiple backplane instances in the same STACKIT project."
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
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/network/backplane?ref=${var.hub.git_ref}"

  project_id           = var.stackit_project_id
  organization_id      = var.stackit_organization_id
  service_account_name = coalesce(var.stackit_service_account_name, "mesh-network")

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
    display_name        = "STACKIT Network"
    symbol              = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/stackit/network/buildingblock/logo.png"
    description         = "Creates a routed STACKIT network inside an existing STACKIT project."
    support_url         = "https://portal.stackit.cloud"
    target_type         = "TENANT_LEVEL"
    run_transparency    = true
    supported_platforms = [{ name = "STACKIT" }]
    readme = chomp(<<-EOT
      This building block creates a **routed STACKIT network** inside your existing STACKIT
      project, so your application can use a dedicated IPv4 subnet without any manual network
      configuration.

      ## 🎯 When to use it

      Use this building block when you:
      - Need a dedicated IPv4 subnet within your STACKIT project for VMs or other networked resources.
      - Want the network to automatically use the address space of the network area your project was placed into.

      ## 💡 Usage examples

      **Example 1: Dedicated subnet for a VM workload**
      An application team provisions a routed network in their STACKIT project to host a group
      of virtual machines that need private IP connectivity within the project's network area.

      **Example 2: Multiple networks per project**
      A project needs separate subnets for different workload tiers. The application team
      instantiates this building block more than once, choosing a different name and prefix
      length for each network.

      ## 📊 Shared Responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Provide the backplane identity used to create the network | ✅ | ❌ |
      | Ensure the target project's network area is already configured | ✅ | ❌ |
      | Choose the network name and prefix length | ❌ | ✅ |
      | Deploy workloads within the network | ❌ | ✅ |
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
        repository_path                = "modules/stackit/network/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      project_id = {
        display_name    = "STACKIT Project ID"
        description     = "STACKIT project ID of the existing project this network will be created in."
        type            = "STRING"
        assignment_type = "PLATFORM_TENANT_ID"
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

      network_name = {
        display_name    = "Network Name"
        description     = "Name of the STACKIT network."
        type            = "STRING"
        assignment_type = "USER_INPUT"
      }

      network_prefix_length = {
        display_name                   = "Network Prefix Length"
        description                    = "IPv4 prefix length for the network (24-28)."
        type                           = "INTEGER"
        assignment_type                = "USER_INPUT"
        default_value                  = jsonencode(25)
        value_validation_regex         = "^(24|25|26|27|28)$"
        validation_regex_error_message = "Prefix length must be one of 24, 25, 26, 27, 28."
      }

      ipv4_nameservers = {
        display_name    = "IPv4 Nameservers"
        description     = "JSON list of IPv4 nameservers for the network. Leave empty to use the network area's default nameservers."
        type            = "CODE"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(jsonencode([]))
      }
    }

    outputs = {
      network_id = {
        display_name    = "Network ID"
        type            = "STRING"
        assignment_type = "NONE"
      }

      network_cidr = {
        display_name    = "Network CIDR"
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
