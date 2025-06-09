resource "aws_iam_user" "backplane" {
  provider = aws.backplane
  name     = var.backplane_user_name
}

resource "aws_iam_access_key" "backplane" {
  provider = aws.backplane
  user     = aws_iam_user.backplane.name
}

# allow the backplane user to assume the backplane role in the management account
data "aws_iam_policy_document" "building_block_service" {
  provider = aws.backplane
  version  = "2012-10-17"
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    resources = [
      aws_iam_role.backplane.arn
    ]
  }
}

resource "aws_iam_user_policy" "assume_roles" {
  provider = aws.backplane
  name     = "assume-roles"
  user     = aws_iam_user.backplane.name
  policy   = data.aws_iam_policy_document.building_block_service.json
}


# IAM policy document for opt-in region management
data "aws_iam_policy_document" "backplane" {
  statement {
    sid = "AccountRegionManagement"
    actions = [
      "account:EnableRegion",
      "account:DisableRegion",
      "account:GetRegionOptStatus",
      "account:ListRegions"
    ]
    resources = ["*"]
  }
}

# configure a trust policy on the management account
data "aws_iam_policy_document" "trust_policy" {
  statement {
    effect = "Allow"
    principals {
      type = "AWS"
      identifiers = [
        aws_iam_user.backplane.arn
      ]
    }
    actions = ["sts:AssumeRole"]
  }
}

# IAM role for opt-in region management
resource "aws_iam_role" "backplane" {
  provider    = aws.management
  name        = var.backplane_role_name
  description = "Role for building block to manage AWS account opt-in regions"

  assume_role_policy = data.aws_iam_policy_document.trust_policy.json
}

resource "aws_iam_role_policy" "backplane" {
  provider = aws.management
  role     = aws_iam_role.backplane.name
  policy   = data.aws_iam_policy_document.backplane.json
}
