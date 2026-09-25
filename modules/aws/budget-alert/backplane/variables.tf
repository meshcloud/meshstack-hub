variable "workload_identity_federation" {
  type = object({
    issuer   = string
    audience = string
    subjects = list(string)
  })
  nullable    = false
  description = <<-EOT
  Trusted identity provider from meshStack that the building block runner federates into.
  Supports multiple subjects and wildcard patterns (e.g., 'system:serviceaccount:namespace:*').
  EOT
}

variable "oidc_provider_arn" {
  type        = string
  nullable    = false
  description = <<-EOT
  ARN of the IAM OIDC provider for the meshStack runner WIF token issuer in this AWS account.
  See .agents/references/aws-backplane.md#the-shared-oidc-provider
  EOT
}

variable "name" {
  type        = string
  nullable    = false
  default     = "budget-alert"
  description = "Name for the federated backplane IAM role and policy (suffixed -role and -assume-roles)."
}

variable "building_block_target_account_access_role_name" {
  type        = string
  nullable    = false
  default     = "building-block-budget-alert"
  description = "Name of the role the backplane assumes in the account the budget is created in."
}

variable "building_block_target_ou_ids" {
  type        = set(string)
  nullable    = false
  description = <<-EOT
  AWS OU IDs whose accounts receive the target role via StackSet. Accounts outside these OUs cannot
  be reached. Pass an empty set for a single-account deployment, where the backplane creates the
  target role in its own account instead.
  EOT
}

variable "stackset_region" {
  type        = string
  nullable    = false
  default     = "eu-central-1"
  description = "AWS region the StackSet instance is deployed in. IAM is global, so this only decides where CloudFormation tracks the stacks."
}
