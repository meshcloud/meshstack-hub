variable "aws_oidc_provider_arn" {
  type        = string
  nullable    = false
  description = <<-EOT
  ARN of the IAM OIDC provider for the meshStack runner WIF token issuer in this AWS account.
  See .agents/references/aws-backplane.md#the-shared-oidc-provider
  EOT
}

variable "aws_target_ou_ids" {
  type        = set(string)
  nullable    = false
  description = "AWS OU IDs whose accounts the building block can create a budget in. Pass an empty set to deploy against a single account; see backplane/README.md."
}

variable "aws_target_account_role_name" {
  type        = string
  nullable    = false
  default     = "building-block-budget-alert"
  description = "Name of the IAM role the building block assumes in the account the budget is created in."
}

variable "backplane_name" {
  type        = string
  nullable    = false
  default     = "aws-budget-alert"
  description = "Name for the federated backplane IAM role and policy."
}

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

output "building_block_definition" {
  description = "BBD is consumed in building block compositions."
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  }
}

# The building block runners share the OIDC issuer and audience of meshStack integrations, so the
# federation settings are read from meshStack rather than hardcoded.
data "meshstack_integrations" "integrations" {}

module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/aws/budget-alert/backplane?ref=${var.hub.git_ref}"

  # The default provider applies against the account hosting the backplane, `aws.management` against
  # the organization's management account. A `providers` argument replaces inheritance wholesale, so
  # both have to be listed.
  providers = {
    aws            = aws
    aws.management = aws.management
  }

  name                                           = var.backplane_name
  oidc_provider_arn                              = var.aws_oidc_provider_arn
  building_block_target_ou_ids                   = var.aws_target_ou_ids
  building_block_target_account_access_role_name = var.aws_target_account_role_name

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
    display_name        = coalesce(var.bbd_display_name, "AWS Budget Alert")
    description         = coalesce(var.bbd_description, "Sends email alerts when an AWS account's spend crosses configurable thresholds of a monthly budget.")
    support_url         = ""
    documentation_url   = ""
    symbol              = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/aws/budget-alert/buildingblock/logo.png"
    target_type         = "TENANT_LEVEL"
    supported_platforms = [{ name = "AWS" }]

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
      This building block creates an **AWS Budget** for your account, so you find out about
      unexpected spend from an email rather than from the invoice.

      ## 🎯 When to use it

      Use this building block when you:
      - Want to be told when your account's monthly AWS spend approaches or exceeds a figure you set.
      - Want a forecast-based warning early in the month, before the spend has actually happened.

      Note that a budget alert only notifies. It never caps or stops spending, and it never disables
      resources.

      ## 💡 Usage examples

      **Example 1: Guarding a development account**
      A team sets a 200 USD monthly budget on their dev account and gets an email once actual spend
      passes 80%, giving them time to shut down a forgotten GPU instance before the month ends.

      **Example 2: Catching a runaway workload early**
      A team keeps the default 100% forecasted threshold, so a job that starts burning budget on day
      three triggers an alert immediately — the forecast crosses the budget long before actual spend
      does.

      ## 📊 Shared Responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Provide the budget automation | ✅ | ❌ |
      | Grant the account permissions it needs | ✅ | ❌ |
      | Choose the monthly budget amount | ❌ | ✅ |
      | Choose the alert thresholds | ❌ | ✅ |
      | Keep the contact email addresses current | ❌ | ✅ |
      | Act on an alert — investigating and reducing spend | ❌ | ✅ |
      EOT
    ))
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"

    implementation = {
      terraform = {
        terraform_version              = "1.12.5"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/aws/budget-alert/buildingblock"
        ref_name                       = var.hub.git_ref
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      AWS_ROLE_ARN = {
        type            = "STRING"
        display_name    = "AWS Role ARN"
        description     = "ARN of the federated backplane role the runner assumes."
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(module.backplane.workload_identity_federation_role)
      }
      AWS_WEB_IDENTITY_TOKEN_FILE = {
        type            = "STRING"
        display_name    = "AWS Web Identity Token File Path"
        description     = "Path to the token file the AWS SDK exchanges for credentials of the backplane role."
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode("/var/run/secrets/workload-identity/aws/token")
      }
      assume_role_name = {
        type            = "STRING"
        display_name    = "Target Account Role Name"
        description     = "Name of the role the backplane assumes in the account the budget is created in."
        assignment_type = "STATIC"
        argument        = jsonencode(module.backplane.role_name)
      }
      account_id = {
        type            = "STRING"
        display_name    = "AWS Account ID"
        description     = "The AWS account whose spend the budget tracks."
        assignment_type = "PLATFORM_TENANT_ID"
      }
      budget_name = {
        type            = "STRING"
        display_name    = "Budget Name"
        description     = "Name of the budget in the AWS console."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("budget_alert")
      }
      monthly_budget_amount = {
        type            = "INTEGER"
        display_name    = "Monthly Budget Amount"
        description     = "The monthly budget for this account, in USD."
        assignment_type = "USER_INPUT"
      }
      contact_emails = {
        type            = "STRING"
        display_name    = "Contact Emails"
        description     = "Comma-separated list of email addresses the budget alerts are sent to (e.g. 'foo@example.com, bar@example.com')."
        assignment_type = "USER_INPUT"
      }
      actual_threshold_percent = {
        type            = "INTEGER"
        display_name    = "Actual Threshold Percent"
        description     = "Percentage of the monthly budget at which spend already incurred triggers an alert."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(80)
      }
      forecasted_threshold_percent = {
        type            = "INTEGER"
        display_name    = "Forecasted Threshold Percent"
        description     = "Percentage of the monthly budget at which spend projected to the end of the month triggers an alert."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(100)
      }
    }

    outputs = {
      budget_id = {
        type            = "STRING"
        display_name    = "Budget ID"
        description     = "Identifier of the created budget"
        assignment_type = "NONE"
      }
      budget_name = {
        type            = "STRING"
        display_name    = "Budget Name"
        description     = "Name of the created budget"
        assignment_type = "NONE"
      }
      budget_amount = {
        type            = "INTEGER"
        display_name    = "Budget Amount"
        description     = "The configured monthly budget amount"
        assignment_type = "NONE"
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
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 6.0.0"

      configuration_aliases = [
        # Forwarded to the backplane, which deploys the target-account role across the organization
        # from here. See backplane/README.md.
        aws.management
      ]
    }
  }
}
