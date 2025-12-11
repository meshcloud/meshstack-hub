data "aws_caller_identity" "current" {}

resource "aws_iam_user" "buildingblock_s3_user" {
  count = var.workload_identity_federation == null ? 1 : 0

  name = "buildingblock-s3-user"
}

data "aws_iam_policy_document" "s3_full_access" {
  statement {
    actions = [
      "s3:*",
    ]

    resources = [
      "arn:aws:s3:::*",
    ]
  }
}

resource "aws_iam_policy" "buildingblock_s3_policy" {
  name        = var.workload_identity_federation == null ? "S3BuildingBlockPolicy" : "S3BuildingBlockFederatedPolicy"
  description = "Policy for the S3 Building Block"
  policy      = data.aws_iam_policy_document.s3_full_access.json
}

resource "aws_iam_user_policy_attachment" "buildingblock_s3_user_policy_attachment" {
  count = var.workload_identity_federation == null ? 1 : 0

  user       = aws_iam_user.buildingblock_s3_user[0].name
  policy_arn = aws_iam_policy.buildingblock_s3_policy.arn
}

resource "aws_iam_access_key" "buildingblock_s3_access_key" {
  count = var.workload_identity_federation == null ? 1 : 0

  user = aws_iam_user.buildingblock_s3_user[0].name
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

  name               = "BuildingBlockS3IdentityFederation"
  assume_role_policy = data.aws_iam_policy_document.workload_identity_federation[0].json
}

resource "aws_iam_role_policy_attachment" "buildingblock_s3" {
  count = var.workload_identity_federation != null ? 1 : 0

  role       = aws_iam_role.assume_federated_role[0].name
  policy_arn = aws_iam_policy.buildingblock_s3_policy.arn
}
