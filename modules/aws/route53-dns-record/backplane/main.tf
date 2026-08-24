data "aws_caller_identity" "current" {}

resource "random_string" "name_suffix" {
  length  = 4
  special = false
  upper   = false
}

data "aws_iam_policy_document" "route53_record_access" {
  # Global Route53 actions that don't support resource-level permissions
  statement {
    effect = "Allow"
    actions = [
      "route53:GetChange",
      "route53:ListHostedZones"
    ]
    resources = ["*"]
  }

  # Zone-specific actions scoped to specific hosted zones
  statement {
    effect = "Allow"
    actions = [
      "route53:ListTagsForResource",
      "route53:GetHostedZone",
      "route53:ChangeResourceRecordSets",
      "route53:ListResourceRecordSets"
    ]
    resources = [
      for zone_id in var.hosted_zone_ids : "arn:aws:route53:::hostedzone/${zone_id}"
    ]
  }
}

locals {
  oidc_provider_arn = try(
    aws_iam_openid_connect_provider.buildingblock_oidc_provider[0].arn,
    data.aws_iam_openid_connect_provider.buildingblock_oidc_provider[0].arn
  )
}

resource "aws_iam_policy" "buildingblock_route53_record_policy" {
  name        = "Route53RecordBuildingBlockFederatedPolicy-${random_string.name_suffix.result}"
  description = "Policy for the Route53 DNS Record Building Block"
  policy      = data.aws_iam_policy_document.route53_record_access.json
}

# Workload Identity Federation

resource "aws_iam_openid_connect_provider" "buildingblock_oidc_provider" {
  count = var.create_oidc_provider ? 1 : 0

  url            = var.workload_identity_federation.issuer
  client_id_list = [var.workload_identity_federation.audience]
}

data "aws_iam_openid_connect_provider" "buildingblock_oidc_provider" {
  count = var.create_oidc_provider ? 0 : 1

  url = var.workload_identity_federation.issuer
}

data "aws_iam_policy_document" "workload_identity_federation" {
  version = "2012-10-17"

  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${trimprefix(var.workload_identity_federation.issuer, "https://")}:aud"

      values = [var.workload_identity_federation.audience]
    }

    condition {
      test     = "StringLike"
      variable = "${trimprefix(var.workload_identity_federation.issuer, "https://")}:sub"

      values = var.workload_identity_federation.subjects
    }
  }
}

resource "aws_iam_role" "assume_federated_role" {
  name               = "BuildingBlockRoute53RecordIdentityFederation-${random_string.name_suffix.result}"
  assume_role_policy = data.aws_iam_policy_document.workload_identity_federation.json
}

resource "aws_iam_role_policy_attachment" "buildingblock_route53_record" {
  role       = aws_iam_role.assume_federated_role.name
  policy_arn = aws_iam_policy.buildingblock_route53_record_policy.arn
}

# Both were count-guarded while the backplane still offered an IAM access key fallback. Without these
# a deployment that is already on the federated path would destroy and recreate its live IAM role.
moved {
  from = aws_iam_role.assume_federated_role[0]
  to   = aws_iam_role.assume_federated_role
}

moved {
  from = aws_iam_role_policy_attachment.buildingblock_route53_record[0]
  to   = aws_iam_role_policy_attachment.buildingblock_route53_record
}
