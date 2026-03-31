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
  description = "Pattern for the email address of newly created AWS accounts. E.g. 'aws+#{workspaceIdentifier}.#{projectIdentifier}@example.com'."
}

variable "aws_replicator_privileged_external_id" {
  type        = string
  sensitive   = true
  description = "Random UUID v4 used as external ID for the replicator role assumption. Enhances security in cross-account setups."
}

variable "aws_cost_explorer_privileged_external_id" {
  type        = string
  sensitive   = true
  description = "Random UUID v4 used as external ID for the cost explorer role assumption. Enhances security in cross-account setups."
}

variable "aws_admin_permission_set_arn" {
  type        = string
  description = "ARN of the AWS IAM Identity Center permission set to assign to admin project members."
}

variable "aws_user_permission_set_arn" {
  type        = string
  description = "ARN of the AWS IAM Identity Center permission set to assign to user project members."
}

variable "aws_reader_permission_set_arn" {
  type        = string
  description = "ARN of the AWS IAM Identity Center permission set to assign to reader project members."
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    platform_name               = optional(string, "aws")
    location_name               = optional(string, "global")
  })
  description = "meshStack ownership and naming settings for this platform integration."
}

data "meshstack_integrations" "integrations" {}

# Creates required IAM users and roles across the three AWS accounts.
# Requires three AWS provider aliases to be configured externally:
#   - aws.management  — your AWS Organizations management account
#   - aws.meshcloud   — the dedicated meshcloud account for IAM users
#   - aws.automation  — the automation account hosting StackSets and Lambda functions
module "aws_meshplatform" {
  source  = "meshcloud/meshplatform/aws"
  version = "~> 0.7.0"

  providers = {
    aws.management = aws.management
    aws.meshcloud  = aws.meshcloud
    aws.automation = aws.automation
  }

  aws_sso_instance_arn = var.aws_sso_instance_arn

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

# Configure meshStack platform
resource "meshstack_platform" "aws" {
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
            organization_root_account_role = module.aws_meshplatform.replicator_management_account_role_arn

            auth = {
              workload_identity = {
                role_arn = module.aws_meshplatform.replicator_workload_identity_federation_role
              }
            }
          }

          account_alias_pattern                             = "#{workspaceIdentifier}-#{projectIdentifier}"
          account_email_pattern                             = var.aws_account_email_pattern
          automation_account_role                           = module.aws_meshplatform.replicator_automation_account_role_arn
          account_access_role                               = module.aws_meshplatform.meshstack_access_role_name
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
                project_role_ref = {
                  name = "admin"
                }
                aws_role            = "admin"
                permission_set_arns = [var.aws_admin_permission_set_arn]
              },
              {
                project_role_ref = {
                  name = "user"
                }
                aws_role            = "user"
                permission_set_arns = [var.aws_user_permission_set_arn]
              },
              {
                project_role_ref = {
                  name = "reader"
                }
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
            organization_root_account_role = module.aws_meshplatform.cost_explorer_management_account_role_arn

            auth = {
              workload_identity = {
                role_arn = module.aws_meshplatform.cost_explorer_identity_federation_role
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
}

resource "meshstack_landingzone" "aws_default" {
  metadata = {
    name               = "${var.meshstack.platform_name}-default"
    owned_by_workspace = var.meshstack.owning_workspace_identifier
  }

  spec = {
    display_name                  = "AWS Default"
    description                   = "Default AWS landing zone"
    automate_deletion_approval    = true
    automate_deletion_replication = true

    platform_ref = {
      uuid = meshstack_platform.aws.metadata.uuid
    }

    platform_properties = {
      aws = {
        aws_target_org_unit_id = "ou-xxxx-xxxxxxxx" # Replace with your target OU ID
        aws_enroll_account     = false

        aws_role_mappings = []
      }
    }
  }
}

terraform {
  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = "~> 0.20.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
