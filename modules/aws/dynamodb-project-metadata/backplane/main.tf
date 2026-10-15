data "aws_caller_identity" "current" {}

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

resource "aws_dynamodb_table" "this" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = var.partition_key_name

  attribute {
    name = var.partition_key_name
    type = "S"
  }
}

resource "aws_iam_openid_connect_provider" "this" {
  url            = var.workload_identity_federation.issuer
  client_id_list = [var.workload_identity_federation.audience]
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.this.arn]
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

locals {
  role_name = "MeshStackDynamoDBWriter-${random_string.suffix.result}"
}

resource "aws_iam_role" "this" {
  name               = local.role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "dynamodb_write" {
  statement {
    effect = "Allow"
    # Full item-level write access on the table. The building block normally retires accounts
    # (mesh_accountStatus = "retired") rather than deleting them, but DeleteItem is granted so the
    # table can also be cleaned up / items removed when needed.
    actions = [
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:GetItem",
    ]
    resources = [aws_dynamodb_table.this.arn]
  }
}

resource "aws_iam_role_policy" "dynamodb_write" {
  name   = "DynamoDBWritePolicy"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.dynamodb_write.json
}
