variable "aws_region" {
  type        = string
  default     = "eu-central-1"
  description = "AWS region for the platform (e.g. 'eu-central-1')."
}

variable "aws_sso_instance_arn" {
  type        = string
  description = "ARN of the AWS IAM Identity Center instance (e.g. 'arn:aws:sso:::instance/ssoins-xxxxxxxxxxxxxxx')."
}

variable "aws_sso_identity_store_id" {
  type        = string
  description = "ID of the AWS IAM Identity Store (e.g. 'd-1234567890')."
}

variable "aws_sso_sign_in_url" {
  type        = string
  description = "AWS IAM Identity Center sign-in URL for end-users (e.g. 'https://d-1234567890.awsapps.com/start')."
}

variable "aws_account_email_pattern" {
  type        = string
  description = "Pattern for the email address of newly created AWS accounts (e.g. 'aws+#{workspaceIdentifier}.#{projectIdentifier}@example.com')."
}

variable "aws_target_org_unit_id" {
  type        = string
  description = "AWS Organizations OU ID where meshStack will enroll accounts (e.g. 'ou-xxxx-xxxxxxxx')."
}

variable "aws_replicator_privileged_external_id" {
  type        = string
  sensitive   = true
  description = "Random UUID v4 used as external ID for the replicator role assumption."
}

variable "aws_cost_explorer_privileged_external_id" {
  type        = string
  sensitive   = true
  description = "Random UUID v4 used as external ID for the cost explorer role assumption."
}

variable "aws_admin_permission_set_arn" {
  type        = string
  description = "ARN of the AWS IAM Identity Center permission set assigned to admin project members."
}

variable "aws_user_permission_set_arn" {
  type        = string
  description = "ARN of the AWS IAM Identity Center permission set assigned to user project members."
}

variable "aws_reader_permission_set_arn" {
  type        = string
  description = "ARN of the AWS IAM Identity Center permission set assigned to reader project members."
}

variable "aws_management_account_id" {
  type        = string
  description = "AWS account ID of the Organizations management account."
}

variable "aws_meshcloud_account_id" {
  type        = string
  description = "AWS account ID of the dedicated meshcloud account for IAM users."
}

variable "aws_automation_account_id" {
  type        = string
  description = "AWS account ID of the automation account hosting StackSets."
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    platform_name               = optional(string, "aws")
    location_name               = optional(string, "global")
    tags                        = optional(map(list(string)), {})
  })
  description = "meshStack ownership and naming settings for this platform integration. Tags are propagated to landing zone metadata."
}

data "meshstack_integrations" "integrations" {}

# Requires three AWS provider aliases configured at the root level:
#   aws.management — AWS Organizations management account
#   aws.meshcloud  — dedicated meshcloud account for IAM users
#   aws.automation — automation account hosting StackSets
#
# Example for the management alias
#  provider "aws" {
#  alias   = "management"
#  profile = "management"
#  region  = var.aws_region
#
module "this" {
  source = "github.com/meshcloud/terraform-aws-meshplatform?ref=v0.7.0"

  providers = {
    aws.management = aws.management
    aws.meshcloud  = aws.meshcloud
    aws.automation = aws.automation
  }

  aws_sso_instance_arn                 = var.aws_sso_instance_arn
  replicator_privileged_external_id    = var.aws_replicator_privileged_external_id
  cost_explorer_privileged_external_id = var.aws_cost_explorer_privileged_external_id

  workload_identity_federation = {
    issuer             = data.meshstack_integrations.integrations.workload_identity_federation.replicator.issuer
    audience           = data.meshstack_integrations.integrations.workload_identity_federation.replicator.aws.audience
    thumbprint         = data.meshstack_integrations.integrations.workload_identity_federation.replicator.aws.thumbprint
    replicator_subject = data.meshstack_integrations.integrations.workload_identity_federation.replicator.subject
    kraken_subject     = data.meshstack_integrations.integrations.workload_identity_federation.metering.subject
  }
}

resource "meshstack_platform" "this" {
  metadata = {
    name               = var.meshstack.platform_name
    owned_by_workspace = var.meshstack.owning_workspace_identifier
  }

  spec = {
    description  = "Amazon Web Services. Create an AWS account."
    display_name = "AWS Account"
    endpoint     = "https://console.aws.amazon.com"

    location_ref = {
      name = var.meshstack.location_name
    }

    # To make this platform visible and accessible to all users, you must request publishing
    # it through the meshStack panel.
    availability = {
      restriction              = "PRIVATE"
      publication_state        = "UNPUBLISHED"
      restricted_to_workspaces = [var.meshstack.owning_workspace_identifier]
    }

    config = {
      aws = {
        region = var.aws_region

        replication = {
          access_config = {
            organization_root_account_role        = module.this.replicator_management_account_role_arn
            organization_root_account_external_id = var.aws_replicator_privileged_external_id

            auth = {
              workload_identity = {
                role_arn = module.this.replicator_workload_identity_federation_role
              }
            }
          }

          account_alias_pattern                             = "#{workspaceIdentifier}-#{projectIdentifier}"
          account_email_pattern                             = var.aws_account_email_pattern
          automation_account_role                           = module.this.replicator_automation_account_role_arn
          account_access_role                               = module.this.meshstack_access_role_name
          self_downgrade_access_role                        = false
          enforce_account_alias                             = false
          wait_for_external_avm                             = false
          skip_user_group_permission_cleanup                = false
          allow_hierarchical_organizational_unit_assignment = false

          aws_identity_store = {
            identity_store_id  = var.aws_sso_identity_store_id
            arn                = var.aws_sso_instance_arn
            group_name_pattern = "#{workspaceIdentifier}.#{projectIdentifier}-#{platformGroupAlias}"
            sign_in_url        = var.aws_sso_sign_in_url

            aws_role_mappings = [
              {
                project_role_ref    = { name = "admin" }
                aws_role            = "admin"
                permission_set_arns = [var.aws_admin_permission_set_arn]
              },
              {
                project_role_ref    = { name = "user" }
                aws_role            = "user"
                permission_set_arns = [var.aws_user_permission_set_arn]
              },
              {
                project_role_ref    = { name = "reader" }
                aws_role            = "reader"
                permission_set_arns = [var.aws_reader_permission_set_arn]
              },
            ]
          }

          tenant_tags = {
            namespace_prefix = "mesh_"
            tag_mappers = [
              {
                key           = "wsid"
                value_pattern = "$${workspaceIdentifier}"
              },
              {
                key           = "project"
                value_pattern = "$${projectIdentifier}"
              },
            ]
          }
        }

        metering = {
          access_config = {
            organization_root_account_role        = module.this.cost_explorer_management_account_role_arn
            organization_root_account_external_id = var.aws_cost_explorer_privileged_external_id

            auth = {
              workload_identity = {
                role_arn = module.this.cost_explorer_identity_federation_role
              }
            }
          }

          filter                            = "NONE"
          reserved_instance_fair_chargeback = false
          savings_plan_fair_chargeback      = false

          processing = {}
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [spec.availability]
  }
}

resource "meshstack_landingzone" "this" {
  metadata = {
    name               = "${var.meshstack.platform_name}-lz"
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name                  = "AWS Default"
    description                   = "Default AWS landing zone"
    automate_deletion_approval    = true
    automate_deletion_replication = true

    platform_ref = meshstack_platform.this.ref

    platform_properties = {
      aws = {
        aws_target_org_unit_id = var.aws_target_org_unit_id
        aws_enroll_account     = false
        aws_role_mappings      = []
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
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.management, aws.meshcloud, aws.automation]
      version               = ">= 6.0"
    }
  }
}
