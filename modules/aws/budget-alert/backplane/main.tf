# A budget belongs to the AWS account whose spend it tracks, so this backplane provides two
# identities: the role the building block runner federates into, and the role it then assumes in the
# account receiving the budget. In an AWS Organization the second one lives in a different account
# per tenant, which is why a StackSet distributes it.

data "aws_caller_identity" "current" {}

locals {
  federated_role_name = "${var.name}-role"

  # With no target OUs there is no organization to distribute the target role to, so the backplane
  # creates it next to itself. That is the single-account deployment: the account hosting the
  # backplane is also the account receiving the budget.
  single_account = length(var.building_block_target_ou_ids) == 0
}

# --- the identity the building block runner federates into -------------------

data "aws_iam_policy_document" "workload_identity_federation" {
  version = "2012-10-17"

  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${trimprefix(var.workload_identity_federation.issuer, "https://")}:aud"
      values   = [var.workload_identity_federation.audience]
    }

    condition {
      test     = "StringLike"
      variable = "${trimprefix(var.workload_identity_federation.issuer, "https://")}:sub"
      values   = var.workload_identity_federation.subjects
    }
  }
}

resource "aws_iam_role" "backplane" {
  name               = local.federated_role_name
  assume_role_policy = data.aws_iam_policy_document.workload_identity_federation.json
}

# The federated role carries no budget permissions of its own — everything it may do, it does
# through the target account's role.
data "aws_iam_policy_document" "assume_target_account_role" {
  version = "2012-10-17"

  statement {
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = ["arn:aws:iam::*:role/${var.building_block_target_account_access_role_name}"]
  }
}

resource "aws_iam_policy" "assume_target_account_role" {
  name   = "${var.name}-assume-roles"
  policy = data.aws_iam_policy_document.assume_target_account_role.json
}

resource "aws_iam_role_policy_attachment" "assume_target_account_role" {
  role       = aws_iam_role.backplane.name
  policy_arn = aws_iam_policy.assume_target_account_role.arn
}

# --- the role in the account that receives the budget ------------------------

locals {
  # One definition for both ways the role reaches a target account.
  target_account_role_policy = {
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["budgets:*"]
      Resource = "*"
    }]
  }
}

data "aws_iam_policy_document" "target_account_role_trust" {
  version = "2012-10-17"

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.backplane.arn]
    }
  }
}

resource "aws_iam_role" "target_account" {
  lifecycle {
    enabled = local.single_account
  }

  name               = var.building_block_target_account_access_role_name
  assume_role_policy = data.aws_iam_policy_document.target_account_role_trust.json
}

resource "aws_iam_policy" "target_account" {
  lifecycle {
    enabled = local.single_account
  }

  name   = var.building_block_target_account_access_role_name
  policy = jsonencode(local.target_account_role_policy)
}

resource "aws_iam_role_policy_attachment" "target_account" {
  lifecycle {
    enabled = local.single_account
  }

  role       = aws_iam_role.target_account.name
  policy_arn = aws_iam_policy.target_account.arn
}

# A StackSet keeps the target role in step with the organization: accounts joining one of the OUs
# receive it without anyone re-applying this module.
resource "aws_cloudformation_stack_set" "permissions_in_target_accounts" {
  lifecycle {
    enabled = !local.single_account

    # CloudFormation picks the administration role itself under SERVICE_MANAGED, and reports a
    # different ARN after every stack update.
    ignore_changes = [administration_role_arn]
  }

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
    AWSTemplateFormatVersion = "2010-09-09"
    Description              = "Grants the building block backplane ${aws_iam_role.backplane.name} access to a managed account."
    Resources = {
      BuildingBlockServiceRolePermissions = {
        Type = "AWS::IAM::Role"
        Properties = {
          RoleName                 = var.building_block_target_account_access_role_name
          AssumeRolePolicyDocument = jsondecode(data.aws_iam_policy_document.target_account_role_trust.json)
          Policies = [{
            PolicyName     = var.building_block_target_account_access_role_name
            PolicyDocument = local.target_account_role_policy
          }]
        }
      }
    }
  })

  capabilities = ["CAPABILITY_IAM", "CAPABILITY_NAMED_IAM"]
}

resource "aws_cloudformation_stack_set_instance" "permissions_in_target_accounts" {
  lifecycle {
    enabled = !local.single_account
  }

  provider = aws.management
  deployment_targets {
    organizational_unit_ids = var.building_block_target_ou_ids
  }

  region         = var.stackset_region
  stack_set_name = aws_cloudformation_stack_set.permissions_in_target_accounts.name
}
