variable "aws_region" {
  type        = string
  default     = "eu-central-1"
  description = "AWS region used by the building block runner provider (Route53 is global, but the provider requires a region)."
}

variable "hosted_zone_ids" {
  type        = list(string)
  description = "List of Route53 hosted zone IDs the building block may manage. Example: [\"ZXXXXXXXXXXXXXXXXX\"]"
}

variable "hosted_zone_names" {
  type        = list(string)
  description = "List of Route53 hosted zone names offered in the zone selector (e.g. [\"example.com\", \"internal.example.com\"]). Must correspond to the hosted zones listed in hosted_zone_ids."
}

variable "private_zone" {
  type        = bool
  default     = false
  description = "Set to true if the Route53 zones are Private Hosted Zones."
}

variable "record_types" {
  type        = list(string)
  default     = ["A", "AAAA"]
  description = "List of DNS record types offered in the record type selector. Alias records only support A and AAAA."
}

variable "create_oidc_provider" {
  type        = bool
  default     = true
  description = "Set to false if the OIDC provider for the meshStack issuer already exists in this AWS account (e.g., created by another backplane). The existing provider will be looked up by URL instead of created."
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
  source = "github.com/meshcloud/meshstack-hub//modules/aws/route53-dns-alias-record/backplane?ref=${var.hub.git_ref}"

  hosted_zone_ids      = var.hosted_zone_ids
  create_oidc_provider = var.create_oidc_provider

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
    display_name      = "AWS Route53 DNS Alias Record"
    description       = "Provides AWS Route53 DNS alias records for routing traffic to AWS resources such as load balancers and CloudFront distributions."
    support_url       = ""
    documentation_url = "https://hub.meshcloud.io/platforms/aws/definitions/route53-dns-alias-record"
    symbol            = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/aws/route53-dns-alias-record/buildingblock/logo.png"
    target_type       = "WORKSPACE_LEVEL"

    readme = chomp(<<-EOT
      This building block creates Route53 alias records, which are AWS-specific DNS records that route traffic to AWS resources (load balancers, CloudFront distributions, S3 websites, etc.).

      ## When to use it?

      - Point custom domains to AWS load balancers (ALB/NLB)
      - Route traffic to CloudFront distributions
      - Create apex/root domain records (e.g. `example.com`)

      ## Shared Responsibilities

      | Responsibility                              | Platform Team | Application Team |
      | ------------------------------------------- | :-----------: | :--------------: |
      | Managing Route53 hosted zones               | ✅            | ❌               |
      | Provisioning DNS alias records              | ❌            | ✅               |
      | Managing record names and target resources  | ❌            | ✅               |
    EOT
    )
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"

    implementation = {
      terraform = {
        terraform_version = "1.11.5"
        repository_url    = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path   = "modules/aws/route53-dns-alias-record/buildingblock"
        ref_name          = var.hub.git_ref
      }
    }

    inputs = {
      zone_name = {
        type              = "SINGLE_SELECT"
        display_name      = "Zone Name"
        description       = "AWS Route53 hosted zone in which the alias record will be created."
        assignment_type   = "USER_INPUT"
        selectable_values = var.hosted_zone_names
      }
      sub = {
        type            = "STRING"
        display_name    = "DNS Record Name"
        description     = "DNS record name, excluding the zone name. Use '@' to create an apex record (e.g. 'example.com' itself)."
        assignment_type = "USER_INPUT"
      }
      type = {
        type              = "SINGLE_SELECT"
        display_name      = "Record Type"
        description       = "DNS record type for the alias."
        assignment_type   = "USER_INPUT"
        selectable_values = var.record_types
      }
      alias_name = {
        type            = "STRING"
        display_name    = "Alias Target DNS Name"
        description     = "The DNS name of the AWS resource to alias (e.g. the DNS name of an ALB or CloudFront distribution)."
        assignment_type = "USER_INPUT"
      }
      alias_zone_id = {
        type            = "STRING"
        display_name    = "Alias Target Hosted Zone ID"
        description     = "The Route53 hosted zone ID of the alias target. AWS resources have well-known zone IDs (see https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-route53-aliastarget.html)."
        assignment_type = "USER_INPUT"
      }
      alias_evaluate_target_health = {
        type            = "BOOLEAN"
        display_name    = "Evaluate Target Health"
        description     = "When enabled, the alias record inherits the health of the referenced AWS resource for automatic failover."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(false)
      }
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
      private_zone = {
        type            = "BOOLEAN"
        display_name    = "Private Zone"
        description     = "Whether the Route53 zones are Private Hosted Zones. Set by the platform team."
        assignment_type = "STATIC"
        argument        = jsonencode(var.private_zone)
      }
    }

    outputs = {
      record_name = {
        type            = "STRING"
        display_name    = "DNS Record Name"
        description     = "The fully qualified domain name (FQDN) of the created alias record."
        assignment_type = "NONE"
      }
      record_type = {
        type            = "STRING"
        display_name    = "Record Type"
        description     = "The type of the DNS alias record."
        assignment_type = "NONE"
      }
      alias_target = {
        type            = "STRING"
        display_name    = "Alias Target"
        description     = "The DNS name of the alias target resource."
        assignment_type = "NONE"
      }
      summary = {
        type            = "STRING"
        display_name    = "Summary"
        description     = "Human-readable summary of the created DNS alias record."
        assignment_type = "SUMMARY"
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
