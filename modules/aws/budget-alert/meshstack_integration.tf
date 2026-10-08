variable "aws_target_ou_ids" {
  type        = set(string)
  description = "AWS Organizations OU IDs whose accounts can receive budget alerts (e.g. ['ou-xxxx-xxxxxxxx']). The backplane deploys the role it assumes into every account of these OUs."
}

variable "backplane_name" {
  type        = string
  default     = "building-block-budget-alert"
  description = "Name of the backplane IAM user and of the IAM role it assumes in the target accounts."
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

# The caller configures both aliases: aws.management deploys the StackSet over the organization,
# aws.backplane hosts the IAM user, typically a dedicated automation account.
module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/aws/budget-alert/backplane?ref=${var.hub.git_ref}"

  providers = {
    aws.management = aws.management
    aws.backplane  = aws.backplane
  }

  backplane_user_name                            = var.backplane_name
  building_block_target_account_access_role_name = var.backplane_name
  building_block_target_ou_ids                   = var.aws_target_ou_ids
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name        = coalesce(var.bbd_display_name, "AWS Budget Alert")
    description         = coalesce(var.bbd_description, "Sets up a monthly budget with email alerts on an AWS account to monitor spending and prevent cost overruns.")
    support_url         = "mailto:support@meshcloud.io"
    documentation_url   = "https://hub.meshcloud.io/platforms/aws/definitions/aws-budget-alert"
    symbol              = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/aws/budget-alert/buildingblock/logo.png"
    target_type         = "TENANT_LEVEL"
    supported_platforms = [{ name = "AWS" }]

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
      This building block sets up a monthly **AWS Budget** on your AWS account and emails the people
      you name when actual spend reaches a threshold, or when the forecast says it will exceed one.

      ## 🎯 When to use it

      Use this building block when you:
      - want to hear about rising cloud costs before the invoice arrives
      - need a cost guardrail on an account without managing AWS Budgets yourself

      ## 💡 Usage examples

      **Example 1: Alert the team at 80% of the budget**
      A development team sets a monthly budget of 500 USD and lists its members' email addresses, so
      everyone gets an email once actual spend passes 80% of it.

      **Example 2: Catch a cost spike early**
      A FinOps engineer adds a forecasted alert at 100%, so a sudden spike is reported while there is
      still time in the month to act on it.

      ## 📊 Shared Responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Provide the automation that creates the budget in the account | ✅ | ❌ |
      | Grant the access the automation needs in the account | ✅ | ❌ |
      | Choose the budget amount and alert thresholds | ❌ | ✅ |
      | Keep the list of alert recipients current | ❌ | ✅ |
      | Act on alerts and adjust spending | ❌ | ✅ |
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
      AWS_ACCESS_KEY_ID = {
        type            = "STRING"
        display_name    = "AWS Access Key ID"
        description     = "Access key ID of the backplane IAM user that assumes the role in the target account."
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(module.backplane.aws_access_key_id)
      }
      AWS_SECRET_ACCESS_KEY = {
        type            = "STRING"
        display_name    = "AWS Secret Access Key"
        description     = "Secret access key of the backplane IAM user."
        assignment_type = "STATIC"
        is_environment  = true
        sensitive = {
          argument = {
            secret_value   = module.backplane.aws_secret_access_key
            secret_version = nonsensitive(sha256(module.backplane.aws_secret_access_key))
          }
        }
      }
      assume_role_name = {
        type            = "STRING"
        display_name    = "Assume Role Name"
        description     = "Name of the IAM role the backplane user assumes in the target account."
        assignment_type = "STATIC"
        argument        = jsonencode(module.backplane.role_name)
      }
      account_id = {
        type            = "STRING"
        display_name    = "AWS Account ID"
        description     = "The AWS account the budget is created in."
        assignment_type = "PLATFORM_TENANT_ID"
      }
      budget_name = {
        type            = "STRING"
        display_name    = "Budget Name"
        description     = "Name of the budget in AWS Budgets."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("budget_alert")
      }
      monthly_budget_amount = {
        type            = "INTEGER"
        display_name    = "Monthly Budget Amount"
        description     = "The monthly budget for this account in USD."
        assignment_type = "USER_INPUT"
      }
      actual_threshold_percent = {
        type            = "INTEGER"
        display_name    = "Actual Threshold Percent"
        description     = "Percentage of the monthly budget at which actual spend triggers an alert (e.g. 80 for 80%)."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(80)
      }
      forecasted_threshold_percent = {
        type            = "INTEGER"
        display_name    = "Forecasted Threshold Percent"
        description     = "Percentage of the monthly budget at which forecasted spend triggers an alert (e.g. 100 for 100%)."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(100)
      }
      contact_emails = {
        type            = "JSON"
        display_name    = "Contact Emails"
        description     = "Email addresses that receive the budget alerts."
        assignment_type = "USER_INPUT"
        json_schema = jsonencode({
          type        = "array"
          title       = "Contact Emails"
          description = "Everyone listed here gets an email when a threshold is reached."
          minItems    = 1
          items = {
            type    = "string"
            title   = "Email"
            pattern = "^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$"
          }
        })
      }
    }

    outputs = {
      budget_name = {
        type            = "STRING"
        display_name    = "Budget Name"
        description     = "The name of the budget."
        assignment_type = "NONE"
      }
      budget_id = {
        type            = "STRING"
        display_name    = "Budget ID"
        description     = "The ID of the budget."
        assignment_type = "NONE"
      }
      budget_amount = {
        type            = "INTEGER"
        display_name    = "Budget Amount"
        description     = "The monthly budget amount in USD."
        assignment_type = "NONE"
      }
    }
  }
}

terraform {
  required_version = ">= 1.12.0"

  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 5.0, < 6.0.0"
      configuration_aliases = [aws.management, aws.backplane]
    }
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.26.2"
    }
  }
}
