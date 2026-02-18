data "aws_caller_identity" "current" {}

resource "aws_iam_user" "buildingblock_route53_alias_record_user" {
  count = var.workload_identity_federation == null ? 1 : 0

  name = "buildingblock-route53-alias-record-user"
}

data "aws_iam_policy_document" "route53_alias_record_access" {
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

resource "aws_iam_policy" "buildingblock_route53_alias_record_policy" {
  name        = var.workload_identity_federation == null ? "Route53AliasRecordBuildingBlockPolicy" : "Route53AliasRecordBuildingBlockFederatedPolicy"
  description = "Policy for the Route53 DNS Alias Record Building Block"
  policy      = data.aws_iam_policy_document.route53_alias_record_access.json
}

resource "aws_iam_user_policy_attachment" "buildingblock_route53_alias_record_user_policy_attachment" {
  count = var.workload_identity_federation == null ? 1 : 0

  user       = aws_iam_user.buildingblock_route53_alias_record_user[0].name
  policy_arn = aws_iam_policy.buildingblock_route53_alias_record_policy.arn
}

resource "aws_iam_access_key" "buildingblock_route53_alias_record_access_key" {
  count = var.workload_identity_federation == null ? 1 : 0

  user = aws_iam_user.buildingblock_route53_alias_record_user[0].name
}

# Workload Identity Federation

resource "aws_iam_openid_connect_provider" "buildingblock_oidc_provider" {
  count = var.workload_identity_federation != null ? 1 : 0

  url            = var.workload_identity_federation.issuer
  client_id_list = [var.workload_identity_federation.audience]
}

data "aws_iam_policy_document" "workload_identity_federation" {
  count   = var.workload_identity_federation != null ? 1 : 0
  version = "2012-10-17"

  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.buildingblock_oidc_provider[0].arn]
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
  count = var.workload_identity_federation != null ? 1 : 0

  name               = "BuildingBlockRoute53AliasRecordIdentityFederation"
  assume_role_policy = data.aws_iam_policy_document.workload_identity_federation[0].json
}

resource "aws_iam_role_policy_attachment" "buildingblock_route53_alias_record" {
  count = var.workload_identity_federation != null ? 1 : 0

  role       = aws_iam_role.assume_federated_role[0].name
  policy_arn = aws_iam_policy.buildingblock_route53_alias_record_policy.arn
}
