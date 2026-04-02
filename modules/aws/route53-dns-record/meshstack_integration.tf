variable "aws_region" {
  type        = string
  default     = "eu-central-1"
  description = "AWS region used by the building block runner provider (Route53 is global, but the provider requires a region)."
}

variable "hosted_zone_ids" {
  type        = list(string)
  description = "List of Route53 hosted zone IDs the building block may manage. Example: [\"ZXXXXXXXXXXXXXXXXX\"]"
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
  default     = {}
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

data "meshstack_integrations" "integrations" {}

module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/aws/route53-dns-record/backplane?ref=${var.hub.git_ref}"

  hosted_zone_ids = var.hosted_zone_ids

  workload_identity_federation = {
    issuer   = data.meshstack_integrations.integrations.workload_identity_federation.replicator.issuer
    audience = data.meshstack_integrations.integrations.workload_identity_federation.replicator.aws.audience
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
    display_name      = "AWS Route53 DNS Record"
    description       = "Provides AWS Route53 DNS records for mapping domain names to IP addresses or other values."
    support_url       = ""
    documentation_url = "https://hub.meshcloud.io/platforms/aws/definitions/route53-dns-record"
    symbol            = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/main/modules/aws/route53-dns-record/buildingblock/logo.png"
    target_type       = "WORKSPACE_LEVEL"

    readme = chomp(<<-EOT
      ## AWS Route53 DNS Record

      This building block creates standard DNS records for mapping domain names to IP addresses or other values.

      ## When to use it?

      - Create DNS records (A, AAAA, CNAME, TXT, MX, SRV, etc.)
      - Point subdomain names to IP addresses or other domains
      - Configure email routing, domain verification, or service discovery

      ## Shared Responsibilities

      | Responsibility                        | Platform Team | Application Team |
      | ------------------------------------- | :-----------: | :--------------: |
      | Managing Route53 hosted zones         | ✅            | ❌               |
      | Provisioning DNS records              | ❌            | ✅               |
      | Managing record values and TTL        | ❌            | ✅               |
    EOT
    )
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"

    implementation = {
      terraform = {
        terraform_version              = "1.9.0"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/aws/route53-dns-record/buildingblock"
        ref_name                       = var.hub.git_ref
        use_mesh_http_backend_fallback = false
      }
    }

    inputs = {
      AWS_ROLE_ARN = {
        type            = "STRING"
        display_name    = "AWS Role ARN"
        description     = "ARN of the AWS IAM role assumed by the building block runner via workload identity federation."
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(module.backplane.workload_identity_federation_role)
      }
      AWS_WEB_IDENTITY_TOKEN_FILE = {
        type            = "STRING"
        display_name    = "AWS Web Identity Token File Path"
        description     = "File path to the AWS web identity token used for workload identity federation."
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode("/var/run/secrets/workload-identity/aws/token")
      }
      region = {
        type            = "STRING"
        display_name    = "AWS Region"
        description     = "AWS region for the provider (Route53 is global; this is used for provider configuration only)."
        assignment_type = "STATIC"
        argument        = jsonencode(var.aws_region)
      }
      zone_name = {
        type            = "STRING"
        display_name    = "Zone Name"
        description     = "AWS Route53 hosted zone name in which the record will be created (e.g. 'example.com')."
        assignment_type = "USER_INPUT"
      }
      private_zone = {
        type            = "BOOLEAN"
        display_name    = "Private Zone"
        description     = "Set to true if the Route53 zone is a Private Hosted Zone."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(false)
      }
      sub = {
        type            = "STRING"
        display_name    = "DNS Record Name"
        description     = "DNS record name, excluding the zone name (e.g. 'api' creates 'api.example.com'). Leave empty for apex records."
        assignment_type = "USER_INPUT"
      }
      type = {
        type            = "STRING"
        display_name    = "Record Type"
        description     = "DNS record type. Supported: A, AAAA, CNAME, MX, SPF, SRV, TXT."
        assignment_type = "USER_INPUT"
      }
      record = {
        type            = "STRING"
        display_name    = "Record Value"
        description     = "The DNS record value (e.g. an IP address for A records, a hostname for CNAME records)."
        assignment_type = "USER_INPUT"
      }
      ttl = {
        type            = "STRING"
        display_name    = "TTL (seconds)"
        description     = "Time-to-live of the record in seconds. Lower values allow faster propagation of changes."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("300")
      }
    }

    outputs = {
      record_name = {
        type            = "STRING"
        display_name    = "DNS Record Name"
        description     = "The fully qualified domain name (FQDN) of the created DNS record."
        assignment_type = "NONE"
      }
      record_type = {
        type            = "STRING"
        display_name    = "Record Type"
        description     = "The type of the DNS record."
        assignment_type = "NONE"
      }
      record_value = {
        type            = "STRING"
        display_name    = "Record Value"
        description     = "The value of the DNS record."
        assignment_type = "NONE"
      }
      summary = {
        type            = "STRING"
        display_name    = "Summary"
        description     = "Human-readable summary of the created DNS record."
        assignment_type = "NONE"
      }
    }
  }
}

terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.32"
    }
    meshstack = {
      source  = "meshcloud/meshstack"
      version = "~> 0.20.0"
    }
  }
}
