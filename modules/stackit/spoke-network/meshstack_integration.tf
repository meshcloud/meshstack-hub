variable "stackit_project_id" {
  type        = string
  description = "STACKIT project ID where the backplane service account will be created."
}

variable "stackit_organization_id" {
  type        = string
  description = "STACKIT organization ID."
}

variable "network_area_id" {
  type        = string
  description = "STACKIT network area ID (from LZA hub) used for spoke network attachment."
}

variable "firewall_next_hop_ip" {
  type        = string
  default     = null
  description = "IPv4 address of the firewall next-hop. Pass null if no firewall is configured (route-optional)."
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    tags                        = optional(map(list(string)), {})
  })
}

variable "hub" {
  type = object({
    git_ref   = optional(string, "main")
    bbd_draft = optional(bool, true)
  })
  const       = true
  default     = {}
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

module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/spoke-network/backplane?ref=${var.hub.git_ref}"

  project_id      = var.stackit_project_id
  organization_id = var.stackit_organization_id
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name        = "STACKIT Spoke Network"
    symbol              = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/stackit/spoke-network/buildingblock/logo.png"
    description         = "Provisions a routed network in an application team's STACKIT project and attaches it to the platform hub network area."
    target_type         = "TENANT_LEVEL"
    supported_platforms = [{ name = "STACKIT" }]
    run_transparency    = true
    readme = chomp(<<-EOT
      This building block provisions a **routed STACKIT network** in your project and attaches it
      to the shared platform hub via the network area, enabling corporate connectivity and controlled
      internet egress.

      ## 🎯 When to use it

      Use this building block when your application:
      - Needs to communicate with other corporate workloads over private IP.
      - Should route internet traffic through the platform firewall (when one is configured).
      - Requires a dedicated IPv4 subnet within the STACKIT project.

      ## 💡 Usage examples

      **Example 1: Backend service on corporate network**
      A microservice needs to call an on-premises API over private IP. Adding the Spoke Network
      building block provisions a /25 subnet in your STACKIT project and connects it to the hub,
      enabling private routing without exposing the service to the public internet.

      **Example 2: Controlled internet egress**
      When the platform firewall is enabled, all outbound traffic from the spoke network passes
      through it, allowing the platform team to enforce egress policies across all application teams.

      ## 📊 Shared Responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Provision the routed network | ✅ | ❌ |
      | Attach network to hub network area | ✅ | ❌ |
      | Configure routing table (when firewall present) | ✅ | ❌ |
      | Choose network prefix length | ❌ | ✅ |
      | Deploy workloads within the network | ❌ | ✅ |
      | Manage security groups and firewall rules per VM | ❌ | ✅ |
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
        repository_path                = "modules/stackit/spoke-network/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      project_id = {
        display_name    = "STACKIT Project ID"
        description     = "STACKIT project ID of the application team's tenant (set automatically from platform tenant identity)."
        type            = "STRING"
        assignment_type = "PLATFORM_TENANT_ID"
      }

      organization_id = {
        display_name    = "Organization ID"
        description     = "STACKIT organization ID."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.stackit_organization_id)
      }

      network_area_id = {
        display_name    = "Network Area ID"
        description     = "STACKIT network area ID of the platform hub."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.network_area_id)
      }

      service_account_key_json = {
        display_name    = "Service Account Key JSON"
        description     = "Service account key for the spoke-network backplane."
        type            = "STRING"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value = module.backplane.service_account_key_json
          }
        }
      }

      firewall_next_hop_ip = {
        display_name    = "Firewall Next-Hop IP"
        description     = "IPv4 address of the firewall next-hop. Null if no firewall is configured."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.firewall_next_hop_ip)
      }

      network_prefix_length = {
        display_name                   = "Network Prefix Length"
        description                    = "IPv4 prefix length for the spoke network (24–28). Determines subnet size: /24 = 254 hosts, /25 = 126, /26 = 62, /27 = 30, /28 = 14."
        type                           = "INTEGER"
        assignment_type                = "USER_INPUT"
        default_value                  = "25"
        value_validation_regex         = "^(24|25|26|27|28)$"
        validation_regex_error_message = "Prefix length must be between 24 and 28."
      }

      ipv4_nameservers = {
        display_name    = "DNS Nameservers"
        description     = "JSON-encoded list of IPv4 DNS nameservers, e.g. '[\"8.8.8.8\",\"8.8.4.4\"]'. Leave blank to use STACKIT defaults."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        mandatory       = false
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

      routing_table_id = {
        display_name    = "Routing Table ID"
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
      version = "~> 0.20.0"
    }
    stackit = {
      source  = "stackitcloud/stackit"
      version = "~> 0.96.0"
    }
  }
}
