resource "aws_organizations_organizational_unit" "bedrock" {
  name      = "bedrock"
  parent_id = var.parent_ou_id
}

# Sonnet 4 is available in eu-south-2 (spain) apparently even though the public docs are not super clear on that
# https://docs.aws.amazon.com/bedrock/latest/userguide/inference-profiles-support.html#inference-profiles-support-user
# eu.anthropic.claude-sonnet-4-20250514-v1:0

locals {
  # see https://docs.aws.amazon.com/bedrock/latest/userguide/model-access-product-ids.html
  allowed_models = [
    "prod-4dlfvry4v5hbi", // Anthropic Claude 3.7 Sonnet
    "prod-m5ilt4siql27k", // Anthropic Claude 3.5 Sonnet
    "prod-4pmewlybdftbs", // Anthropic Claude 4.0 Sonnet
    "prod-5ukwuglpt66kg", // Anthropic Claude 4.6 Sonnet
    "prod-xdkflymybwmvi", // Anthropic Claude 4.5 Haiku
  ]

  # EU regions where Bedrock is allowed
  allowed_eu_regions = [
    "eu-west-1",    // Ireland
    "eu-west-2",    // London
    "eu-west-3",    // Paris
    "eu-central-1", // Frankfurt
    "eu-north-1",   // Stockholm
    "eu-south-1",   // Milan
    "eu-south-2",   // Spain
    "eu-central-2", // Zurich
  ]
}

data "aws_iam_policy_document" "only_bedrock" {

  # Restrict Bedrock usage to EU regions only
  statement {
    sid    = "DenyBedrockOutsideEURegions"
    effect = "Deny"
    actions = [
      "bedrock:*"
    ]
    resources = ["*"]
    condition {
      test     = "ForAnyValue:StringNotEquals"
      variable = "aws:RequestedRegion"
      values   = local.allowed_eu_regions
    }
  }

  # 3rd party bedrock models like claude from anthropic need to be enabled via marketplace
  # see https://docs.aws.amazon.com/bedrock/latest/userguide/model-access-permissions.html
  # NOTE: there are also some issues with payment methods for EMEA customers, see https://repost.aws/questions/QU0UOsutrWSSS4nOqgHcIUJg/invalid-payment-instrument-after-requesting-model-access-in-amazon-bedrock
  # This needs to be configured correctly on the AWS Organization payer account.
  statement {
    sid    = "DenyMarketplaceActionsExceptForAllowedModels"
    effect = "Deny"
    actions = [
      "aws-marketplace:Subscribe",
      "aws-marketplace:Unsubscribe",
      "aws-marketplace:ViewSubscriptions"
    ]
    resources = ["*"]
    condition {
      test     = "ForAnyValue:StringNotEquals"
      variable = "aws-marketplace:ProductId"
      values   = local.allowed_models
    }
  }

  statement {
    sid    = "DenyAllExceptBedrockRelated"
    effect = "Deny"
    not_actions = [
      "bedrock:*",         // Allow all Bedrock actions
      "aws-marketplace:*", // Required for marketplace subscriptions that enable model access
      "logs:*",            // Required for logging
      "iam:*",             // Make no restriction on AWS IAM functionality which is basic for AWS functioning
      "ce:*",              // For Cost Explorer
      "budgets:*",         // For Budgets
      "cloudformation:*",  // Required to enable stacksets deployed from the organization
    ]
    resources = ["*"]
  }
}

resource "aws_organizations_policy" "only_bedrock" {
  name        = "only_bedrock"
  description = "Block access to all services except AWS Bedrock and related services for LLM model access."
  content     = data.aws_iam_policy_document.only_bedrock.json
}

resource "aws_organizations_policy_attachment" "only_bedrock" {
  policy_id = aws_organizations_policy.only_bedrock.id
  target_id = aws_organizations_organizational_unit.bedrock.id
}
