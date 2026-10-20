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
  description = "T Cloud Public domain (account) name, e.g. `OTC-EU-DE-00000000001000000000`."
}

variable "otc_region" {
  type        = string
  default     = "eu-de"
  description = "T Cloud Public region the network is created in."
}

variable "otc_auth_url" {
  type        = string
  default     = "https://iam.eu-de.otc.t-systems.com/v3"
  description = "IAM endpoint the building block authenticates against."
}

variable "workload_identity_name" {
  type        = string
  default     = "meshstack-network"
  description = "Name of the identity provider and IAM group the building block signs in through. Unique across the domain."
}

variable "otc_platform_type" {
  type        = string
  default     = "OTC"
  description = "Name of the custom meshStack platform type the application teams' tenants live on."
}

variable "building_block_runner_uuid" {
  type        = string
  default     = null
  description = "Runs this building block on the given meshStack building block runner instead of the shared one meshStack hosts."
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

# Runs sign in through workload identity federation, so the definition carries no access key. This
# module's own provider credentials only set up the identity provider and its group.
module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/otc/network/backplane?ref=${var.hub.git_ref}"

  name = var.workload_identity_name
  workload_identity_federation = {
    issuer   = meshstack_building_block_definition.this.version_latest.workload_identity_federation.issuer
    subject  = meshstack_building_block_definition.this.version_latest.workload_identity_federation.subject
    audience = meshstack_building_block_definition.this.version_latest.workload_identity_federation.gcp.audience
  }
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
    display_name        = coalesce(var.bbd_display_name, "T Cloud Public Network")
    symbol              = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/otc/network/buildingblock/logo.png"
    description         = coalesce(var.bbd_description, "Creates a VPC with one subnet in your project, and optionally a NAT gateway for outbound internet access.")
    support_url         = "https://console.otc.t-systems.com"
    target_type         = "TENANT_LEVEL"
    run_transparency    = true
    supported_platforms = [{ name = var.otc_platform_type }]

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
    This building block creates a private network in your T Cloud Public project: a VPC with one
    subnet, both under the name you choose. Optionally it adds a NAT gateway, so servers in the
    subnet reach the internet without public IPs of their own.

    ## 🎯 When to use it

    Use this building block when you:
    - need a network before ordering a database (RDS) or a Kubernetes cluster (CCE) in your project
    - want your servers to download packages or call external APIs without exposing them publicly

    ## 💡 Usage examples

    **Example 1: Network for a database**
    You order this building block with the default name `app`, then order an RDS database and enter
    `app` as its network name. The database lands in your subnet, reachable only from inside it.

    **Example 2: Allow-listed outbound traffic**
    Your application calls a partner API that only accepts known IPs. With the NAT gateway enabled,
    all outbound traffic leaves through one public IP, shown in the building block's summary.

    ## 📊 Shared Responsibility

    | Responsibility | Platform Team | Application Team |
    |---|:---:|:---:|
    | Provide the building block and the credentials it runs with | ✅ | ❌ |
    | Create the VPC, subnet and NAT gateway | ✅ | ❌ |
    | Choose IP ranges that do not overlap with networks you connect to | ❌ | ✅ |
    | Security groups and firewall rules of your servers | ❌ | ✅ |
    | Cost of the NAT gateway and its elastic IP | ❌ | ✅ |
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
        repository_path                = "modules/otc/network/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
        pre_run_script                 = file("${path.module}/../workload-identity/prerun.sh")
      }
    }

    inputs = {
      project_id = {
        display_name    = "Project ID"
        description     = "Project the network is created in."
        type            = "STRING"
        assignment_type = "PLATFORM_TENANT_ID"
      }

      region = {
        display_name    = "Region"
        description     = "Region of the project."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.otc_region)
      }

      name = {
        display_name                   = "Network Name"
        description                    = "Name of the VPC and its subnet. Enter it again when you order a database or Kubernetes cluster in this project."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        default_value                  = jsonencode("app")
        value_validation_regex         = "^[a-zA-Z0-9_-]{1,56}$"
        validation_regex_error_message = "1-56 letters, digits, dashes or underscores."
      }

      cidr_block = {
        display_name    = "VPC IP Range"
        description     = "IP range of the VPC, in CIDR notation."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("10.0.0.0/16")
      }

      subnet_cidr = {
        display_name    = "Subnet IP Range"
        description     = "IP range of the subnet, inside the VPC's range."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("10.0.0.0/24")
      }

      snat_enabled = {
        display_name           = "NAT Gateway"
        description            = "Adds a NAT gateway, so servers in the subnet reach the internet through one public IP."
        type                   = "BOOLEAN"
        assignment_type        = "USER_INPUT"
        default_value          = jsonencode(true)
        updateable_by_consumer = true
      }

      OS_AUTH_URL = {
        display_name    = "OTC Auth URL"
        description     = "IAM endpoint the provider authenticates against."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(var.otc_auth_url)
      }

      OS_DOMAIN_NAME = {
        display_name    = "OTC Domain Name"
        description     = "T Cloud Public domain the building block acts in."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(var.otc_domain_name)
      }

      OTC_IDENTITY_PROVIDER = {
        display_name    = "OTC Identity Provider"
        description     = "Identity provider the pre-run script exchanges the run token at."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(var.workload_identity_name)
      }
    }

    outputs = {
      vpc_id = {
        display_name    = "VPC ID"
        type            = "STRING"
        assignment_type = "NONE"
      }

      subnet_id = {
        display_name    = "Subnet Network ID"
        type            = "STRING"
        assignment_type = "NONE"
      }

      subnet_cidr = {
        display_name    = "Subnet IP Range"
        type            = "STRING"
        assignment_type = "NONE"
      }

      snat_ip = {
        display_name    = "NAT Gateway IP"
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
