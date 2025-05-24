# AWS Budget Alert Backplane
# This module creates necessary IAM Users and role setup so that we have an IAM user that can deploy budget alerts
# to any account in the target OU.

# user referenced in building block definition
resource "aws_iam_user" "backplane" {
  provider = aws.backplane
  name     = var.backplane_user_name
}

resource "aws_iam_access_key" "backplane" {
  provider = aws.backplane
  user     = aws_iam_user.backplane.name
}

data "aws_partition" "current" {}

# access building block service role in target accounts
data "aws_iam_policy_document" "building_block_service" {
  provider = aws.backplane
  version  = "2012-10-17"
  statement {
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = ["arn:${data.aws_partition.current.partition}:iam::*:role/${var.building_block_target_account_access_role_name}"]
  }
}

resource "aws_iam_user_policy" "assume_roles" {
  provider = aws.backplane
  name     = "assume-roles"
  user     = aws_iam_user.backplane.name
  policy   = data.aws_iam_policy_document.building_block_service.json
}


# this stackset automatically deploys the building block backplane role to target accounts
resource "aws_cloudformation_stack_set" "permissions_in_target_accounts" {
  provider         = aws.management
  name             = var.building_block_target_account_access_role_name
  permission_model = "SERVICE_MANAGED"
  auto_deployment {
    enabled                          = true
    retain_stacks_on_account_removal = false
  }
  operation_preferences {
    failure_tolerance_count = 50
    max_concurrent_count    = 50
  }

  template_body = jsonencode({
    AWSTemplateFormatVersion = "2010-09-09",
    Description              = "Grants the building block backplane ${aws_iam_user.backplane.name} access to a managed account.",
    Resources = {
      BuildingBlockServiceRolePermissions = {
        Type = "AWS::IAM::Role",
        Properties = {
          RoleName = var.building_block_target_account_access_role_name,
          AssumeRolePolicyDocument = {
            Version = "2012-10-17",
            Statement = [
              {
                Effect = "Allow",
                Principal = {
                  AWS = aws_iam_user.backplane.arn
                },
                Action = "sts:AssumeRole"
              }
            ]
          },
          Policies = [
            {
              PolicyName = var.building_block_target_account_access_role_name
              PolicyDocument = {
                Version = "2012-10-17",
                Statement = [
                  {
                    Effect = "Allow",
                    Action = [
                      "budgets:*",
                    ],
                    Resource = "*"
                  }
                ]
              }
            }
          ]
        }
      }
    }
  })

  capabilities = ["CAPABILITY_IAM", "CAPABILITY_NAMED_IAM"]

  #TODO: each time the stack is updated, the ARN of the role changes didn't found out yet
  lifecycle {
    ignore_changes = [administration_role_arn]
  }
}

resource "aws_cloudformation_stack_set_instance" "permissions_in_target_accounts" {
  provider = aws.management
  deployment_targets {
    organizational_unit_ids = var.building_block_target_ou_ids
  }

  region         = "eu-central-1"
  stack_set_name = aws_cloudformation_stack_set.permissions_in_target_accounts.name
}
