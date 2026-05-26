---
description: AWS backplane identity conventions for meshstack-hub modules under modules/aws/. Covers WIF (OIDC + IAM role) and cross-account (IAM user + CloudFormation StackSet) patterns, required variables/outputs, meshstack_integration.tf wiring, and the AWS backplane checklist.
---

# AWS Backplane Identity Conventions

AWS backplanes use one of two identity patterns depending on whether the building block needs to access a single account or operate across multiple accounts in an AWS Organization.

## Pattern A: Workload Identity Federation (WIF) — Single Account

Use WIF when the building block acts within a single AWS account (the backplane account or a shared services account). This is the **preferred pattern** — it eliminates long-lived credentials.

### Rationale

- **No secrets rotation**: WIF tokens are short-lived JWTs issued by meshStack; no access keys to manage.
- **BBD-scoped trust**: The IAM role trust policy is scoped to the specific building block definition UUID, preventing cross-BBD token reuse.
- **OIDC-native**: AWS supports federated OIDC identities via `aws_iam_openid_connect_provider` out of the box.
- **Shared OIDC provider**: Multiple backplanes can share a single OIDC provider in the same AWS account using `create_oidc_provider = false`.

### Implementation Pattern

```hcl
# backplane/main.tf — WIF-based automation principal

data "aws_caller_identity" "current" {}

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

resource "aws_iam_openid_connect_provider" "backplane" {
  count = var.create_oidc_provider ? 1 : 0

  url            = var.workload_identity_federation.issuer
  client_id_list = [var.workload_identity_federation.audience]
}

data "aws_iam_openid_connect_provider" "backplane" {
  count = var.create_oidc_provider ? 0 : 1
  url   = var.workload_identity_federation.issuer
}

locals {
  oidc_provider_arn = try(
    aws_iam_openid_connect_provider.backplane[0].arn,
    data.aws_iam_openid_connect_provider.backplane[0].arn
  )
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
  name               = "BuildingBlock<Service>Federation-${random_string.suffix.result}"
  assume_role_policy = data.aws_iam_policy_document.workload_identity_federation.json
}

# Attach a service-specific policy to aws_iam_role.backplane
```

### Backplane Variables (WIF)

```hcl
variable "workload_identity_federation" {
  type = object({
    issuer   = string
    audience = string
    subjects = list(string)
  })
  nullable    = false
  description = "WIF issuer, audience, and subjects for federated authentication."
}

variable "create_oidc_provider" {
  type        = bool
  default     = true
  description = "Set to false if the OIDC provider for the meshStack issuer already exists in this AWS account (e.g., created by another backplane). The existing provider will be looked up by URL instead of created."
}
```

### Backplane Outputs (WIF)

```hcl
output "workload_identity_federation_role" {
  description = "ARN of the IAM role assumed by the building block runner via WIF."
  # Manually construct the ARN to avoid a dependency cycle: the role name contains a random suffix
  # determined at apply time, while the BBD UUID (used in WIF subjects) depends on plan output.
  value = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/BuildingBlock<Service>Federation-${random_string.suffix.result}"
}
```

---

## Pattern B: IAM Users + CloudFormation StackSets — Cross-Account (Org-Wide)

Use this pattern when the building block must act in **many target accounts** across an AWS Organization (e.g., setting account contacts, deploying budget alerts). A StackSet automatically deploys an assumable IAM role to every account in the target OUs.

### Rationale

- **StackSet-native distribution**: AWS CloudFormation StackSets with `SERVICE_MANAGED` permission model propagate cross-account roles automatically as accounts join OUs.
- **OU-scoped access**: Access is limited to the specified OUs; accounts outside those OUs cannot be reached.
- **Minimal IAM user**: The IAM user in the backplane account only holds `sts:AssumeRole` on the specific role name — no direct service permissions.

### Implementation Pattern

```hcl
# backplane/main.tf — IAM user + CloudFormation StackSet pattern

resource "aws_iam_user" "backplane" {
  provider = aws.backplane
  name     = var.backplane_user_name
}

resource "aws_iam_access_key" "backplane" {
  provider = aws.backplane
  user     = aws_iam_user.backplane.name
}

data "aws_partition" "current" {
  provider = aws.backplane
}

data "aws_iam_policy_document" "assume_roles" {
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
  policy   = data.aws_iam_policy_document.assume_roles.json
}

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
    AWSTemplateFormatVersion = "2010-09-09"
    Resources = {
      BuildingBlockRole = {
        Type = "AWS::IAM::Role"
        Properties = {
          RoleName = var.building_block_target_account_access_role_name
          AssumeRolePolicyDocument = {
            Version = "2012-10-17"
            Statement = [{
              Effect    = "Allow"
              Principal = { AWS = aws_iam_user.backplane.arn }
              Action    = "sts:AssumeRole"
            }]
          }
          Policies = [{
            PolicyName = var.building_block_target_account_access_role_name
            PolicyDocument = {
              Version   = "2012-10-17"
              Statement = [{ Effect = "Allow", Action = [ /* service-specific actions */ ], Resource = "*" }]
            }
          }]
        }
      }
    }
  })

  capabilities = ["CAPABILITY_IAM", "CAPABILITY_NAMED_IAM"]

  lifecycle {
    ignore_changes = [administration_role_arn]
  }
}

resource "aws_cloudformation_stack_set_instance" "permissions_in_target_accounts" {
  provider = aws.management
  deployment_targets {
    organizational_unit_ids = var.building_block_target_ou_ids
  }
  region         = var.stackset_region
  stack_set_name = aws_cloudformation_stack_set.permissions_in_target_accounts.name
}
```

This pattern requires two provider aliases declared in `versions.tf`:
- `aws.management` — the AWS Organizations management account (or delegated admin) that can deploy StackSets
- `aws.backplane` — the account that hosts the IAM user

### Backplane Variables (Cross-Account)

```hcl
variable "backplane_user_name" {
  type        = string
  nullable    = false
  description = "Name for the IAM user in the backplane account."
}

variable "building_block_target_account_access_role_name" {
  type        = string
  nullable    = false
  description = "Name of the IAM role deployed by StackSet to each target account. The backplane IAM user assumes this role."
}

variable "building_block_target_ou_ids" {
  type        = set(string)
  nullable    = false
  description = "AWS OU IDs whose accounts receive the target role via StackSet."
}

variable "stackset_region" {
  type        = string
  default     = "eu-central-1"
  description = "AWS region for StackSet instance deployment."
}
```

### Backplane Outputs (Cross-Account)

```hcl
output "aws_access_key_id" {
  description = "Access key ID for the IAM user."
  value       = aws_iam_access_key.backplane.id
}

output "aws_secret_access_key" {
  sensitive   = true
  description = "Secret access key for the IAM user."
  value       = aws_iam_access_key.backplane.secret
}

output "role_name" {
  description = "Name of the IAM role assumed in target accounts."
  value       = var.building_block_target_account_access_role_name
}
```

---

## What to Avoid

- ❌ Long-lived IAM access keys for single-account building blocks — use WIF (Pattern A) instead
- ❌ Hardcoded AWS account IDs or region names in `main.tf` — use `data "aws_caller_identity"` and variables
- ❌ Overly broad IAM policies (`"*"` actions on `"*"` resources) — scope to minimum required actions and resources
- ❌ `retain_stacks_on_account_removal = true` in StackSets — orphaned roles in removed accounts are a security risk

---

## `meshstack_integration.tf` Wiring (AWS)

### WIF pattern

```hcl
module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/aws/<service>/backplane?ref=${var.hub.git_ref}"

  create_oidc_provider = var.create_oidc_provider

  workload_identity_federation = {
    issuer   = data.meshstack_integrations.integrations.workload_identity_federation.replicator.issuer
    audience = data.meshstack_integrations.integrations.workload_identity_federation.replicator.aws.audience
    subjects = [
      "${trimsuffix(data.meshstack_integrations.integrations.workload_identity_federation.replicator.subject, ":replicator")}:workspace.${var.meshstack.owning_workspace_identifier}.buildingblockdefinition.${meshstack_building_block_definition.this.metadata.uuid}"
    ]
  }
}

# In the BBD inputs:
AWS_ROLE_ARN = {
  type            = "STRING"
  assignment_type = "STATIC"
  is_environment  = true
  argument        = jsonencode(module.backplane.workload_identity_federation_role)
}
AWS_WEB_IDENTITY_TOKEN_FILE = {
  type            = "STRING"
  assignment_type = "STATIC"
  is_environment  = true
  argument        = jsonencode("/var/run/secrets/workload-identity/aws/token")
}
```

### Cross-account (StackSet) pattern

```hcl
# In the BBD inputs:
AWS_ACCESS_KEY_ID = {
  type            = "STRING"
  assignment_type = "STATIC"
  is_environment  = true
  argument        = jsonencode(module.backplane.aws_access_key_id)
}
AWS_SECRET_ACCESS_KEY = {
  type            = "STRING"
  assignment_type = "STATIC"
  is_environment  = true
  is_secret       = true
  argument        = jsonencode(module.backplane.aws_secret_access_key)
}
role_name = {
  type            = "STRING"
  assignment_type = "STATIC"
  argument        = jsonencode(module.backplane.role_name)
}
```

---

## Checklist for AWS Backplanes

**WIF pattern (Pattern A):**
- [ ] Uses `aws_iam_openid_connect_provider` (not a hardcoded ARN)
- [ ] `create_oidc_provider` variable present to allow sharing across backplanes
- [ ] `workload_identity_federation` variable is non-nullable
- [ ] Trust policy scopes `sub` condition to the specific BBD UUID via meshStack WIF subjects
- [ ] Role ARN output is named `workload_identity_federation_role`
- [ ] ARN is manually constructed (not from resource attribute) to avoid dependency cycles
- [ ] Integration wires `AWS_ROLE_ARN` and `AWS_WEB_IDENTITY_TOKEN_FILE` as environment inputs

**Cross-account StackSet pattern (Pattern B):**
- [ ] Two provider aliases declared: `aws.management` and `aws.backplane`
- [ ] StackSet uses `SERVICE_MANAGED` permission model with `auto_deployment.enabled = true`
- [ ] `retain_stacks_on_account_removal = false`
- [ ] `lifecycle { ignore_changes = [administration_role_arn] }` on the StackSet resource
- [ ] IAM user policy grants only `sts:AssumeRole` on the specific role name pattern (no direct service access)
- [ ] Outputs: `aws_access_key_id`, `aws_secret_access_key` (sensitive), `role_name`
- [ ] Integration wires `AWS_SECRET_ACCESS_KEY` with `is_secret = true`
