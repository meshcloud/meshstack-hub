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
- **Shared OIDC provider**: every backplane in an account trusts the provider that `modules/aws/oidc-provider` registers for an issuer, and finds it by the issuer.

<!-- scorecard-checks: aws_wif_external_oidc_provider, aws_oidc_provider_notice -->
### The shared OIDC provider

**A WIF backplane does not create its OIDC provider. It looks up the provider of each issuer it
trusts.**

AWS registers one OIDC provider per issuer URL per AWS account. A meshStack runner has one issuer,
so an account has room for exactly one provider for it no matter how many building block backplanes
federate through it. A backplane that creates its own is claiming shared infrastructure: the second
backplane in the account fails with `EntityAlreadyExists`, and destroying whichever one owns it
breaks every other backplane there.

So it is deployed separately, once per issuer in each AWS account that hosts backplanes:

```hcl
module "meshstack_oidc_provider" {
  source = "github.com/meshcloud/meshstack-hub//modules/aws/oidc-provider?ref=main"
}
```

`modules/aws/oidc-provider` takes the runners' `issuer` and their `audiences` as its one input, copied
from that runner's `meshstack_building_block_runner` data source, and reads the
thumbprint from the issuer's own TLS chain, so the issuer URL has to be reachable from wherever it
runs. To register a self-hosted runner's issuer pass that runner's values, and then pass its
reference as `meshstack.runner_ref` to every building block module running on it.

A backplane trusts one identity per runner, see
[Trusted runners](meshstack-integration.md#trusted-runners). It reads the provider of each issuer
with `data "aws_iam_openid_connect_provider"`, keyed by the issuer, because the ARN of a provider
follows from its issuer. So the caller passes no ARN, and a definition that moves to a runner with
another issuer can't keep the provider of the old one.

- The provider of every issuer must exist before the backplane is planned. Otherwise the plan fails
  in the lookup. A root module that applies both adds `depends_on = [module.meshstack_oidc_provider]`
  to the module that holds the backplane.
- The lookup needs `iam:ListOpenIDConnectProviders` and `iam:GetOpenIDConnectProvider`.
- A caller that uses a backplane directly can still pass one identity in
  `workload_identity_federation` together with `oidc_provider_arn`. The backplane then does no
  lookup for it.

This is where AWS differs from the other providers, and why the repetition is not the same kind of
repetition: an Azure federated identity credential is a child of its UAMI and a GCP workload
identity pool is a named per-project resource, so each module can own its own and none of them can
collide. Only AWS has an account-level singleton keyed by the issuer URL.

#### Migrating an account whose provider lives in a backplane's state

No destroy is needed. Ship a `removed` block in the backplane so the next apply forgets the
provider instead of deleting it:

```hcl
removed {
  from = aws_iam_openid_connect_provider.buildingblock_oidc_provider

  lifecycle {
    destroy = false
  }
}
```

Then `import` the provider into the root that applies `modules/aws/oidc-provider`. The backplanes
that used to create it find it by its issuer.

<!-- scorecard-checks: aws_wif_subject_condition -->
### Implementation Pattern (WIF)

```hcl
# backplane/main.tf — WIF-based automation principal

data "aws_caller_identity" "current" {}

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

# AWS has one OIDC provider per issuer in an account, so the lookup is keyed by the issuer.
data "aws_iam_openid_connect_provider" "runner" {
  for_each = toset(var.runner_identities[*].issuer)

  url = each.key
}

locals {
  # One entry per statement of the trust policy.
  trusted_identities = concat(
    var.workload_identity_federation == null ? [] : [{
      oidc_provider_arn = var.oidc_provider_arn
      issuer            = var.workload_identity_federation.issuer
      audience          = var.workload_identity_federation.audience
      subjects          = var.workload_identity_federation.subjects
    }],
    [
      for identity in var.runner_identities : {
        oidc_provider_arn = data.aws_iam_openid_connect_provider.runner[identity.issuer].arn
        issuer            = identity.issuer
        audience          = identity.audience
        subjects          = [identity.subject]
      }
      # No version of the definition runs on this runner, so no run presents its identity.
      if identity.subject != null
    ],
  )
}

data "aws_iam_policy_document" "workload_identity_federation" {
  version = "2012-10-17"

  lifecycle {
    precondition {
      condition     = length(local.trusted_identities) > 0
      error_message = "The role would trust no identity. Pass workload_identity_federation, or runner_identities with at least one subject. A subject is null when no version of the definition runs on that runner."
    }

    precondition {
      condition     = var.workload_identity_federation == null || var.oidc_provider_arn != null
      error_message = "workload_identity_federation needs oidc_provider_arn."
    }
  }

  dynamic "statement" {
    for_each = local.trusted_identities

    content {
      effect = "Allow"
      principals {
        type        = "Federated"
        identifiers = [statement.value.oidc_provider_arn]
      }
      actions = ["sts:AssumeRoleWithWebIdentity"]

      condition {
        test     = "StringEquals"
        variable = "${trimprefix(statement.value.issuer, "https://")}:aud"
        values   = [statement.value.audience]
      }

      condition {
        test     = "StringLike"
        variable = "${trimprefix(statement.value.issuer, "https://")}:sub"
        values   = statement.value.subjects
      }
    }
  }
}

resource "aws_iam_role" "backplane" {
  name               = "BuildingBlock<Service>Federation-${random_string.suffix.result}"
  assume_role_policy = data.aws_iam_policy_document.workload_identity_federation.json
}

# Attach a service-specific policy to aws_iam_role.backplane
```

The trust policy has one statement per identity. With one runner it is the same policy as before
the list existed, so a deployment that sets no `meshstack.trusted_runner_refs` gets an empty plan.

<!-- scorecard-checks: aws_wif_nonnullable -->
### Backplane Variables (WIF)

```hcl
variable "runner_identities" {
  type = list(object({
    issuer   = string
    audience = string
    subject  = string
  }))
  default     = []
  nullable    = false
  description = <<-EOT
  The meshStack identities the role trusts, one per building block runner: the output `identities` of
  modules/meshstack/runner-identity. An entry with a null subject is skipped.
  The backplane looks up the IAM OIDC provider of each issuer in this AWS account.
  See .agents/references/aws-backplane.md#the-shared-oidc-provider
  EOT
}

# The two variables below are for a caller that uses the backplane without the integration.
variable "workload_identity_federation" {
  type = object({
    issuer   = string
    audience = string
    subjects = list(string)
  })
  default     = null
  description = <<-EOT
  One more identity the role trusts, for a caller that does not use `runner_identities`. It needs `oidc_provider_arn`.
  Supports multiple subjects and wildcard patterns (e.g., 'system:serviceaccount:namespace:*').
  EOT
}

variable "oidc_provider_arn" {
  type        = string
  default     = null
  description = <<-EOT
  ARN of the IAM OIDC provider for the issuer of `workload_identity_federation` in this AWS account.
  See .agents/references/aws-backplane.md#the-shared-oidc-provider
  EOT
}
```

The last line of the `runner_identities` description is fixed. A missing provider fails the plan in
the lookup, and this link tells the platform engineer what to apply first. The scorecard enforces it.

<!-- scorecard-checks: aws_wif_role_output -->
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

<!-- scorecard-checks: aws_cross_account_provider_aliases, aws_stackset_auto_deployment -->
### Implementation Pattern (Cross-Account)

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

<!-- scorecard-checks: aws_cross_account_outputs -->
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

<!-- scorecard-checks: aws_wif_no_access_key -->
## What to Avoid

- ❌ Long-lived IAM access keys for single-account building blocks — use WIF (Pattern A) instead
- ❌ Hardcoded AWS account IDs or region names in `main.tf` — use `data "aws_caller_identity"` and variables
- ❌ Overly broad IAM policies (`"*"` actions on `"*"` resources) — scope to minimum required actions and resources
- ❌ `retain_stacks_on_account_removal = true` in StackSets — orphaned roles in removed accounts are a security risk

The first of these has a specific shape worth naming: a `workload_identity_federation` variable that
defaults to `null`, with `count = var.workload_identity_federation == null ? 1 : 0` selecting an
`aws_iam_user` and an `aws_iam_access_key` on the null branch. That is a single-account backplane
keeping a long-lived key as a fallback, and it is what the bullet forbids — the choice is between the
two patterns, not between federation and a key inside Pattern A. Pattern B's access key is a
different thing: it is the only credential that pattern has, and it authenticates a principal whose
sole permission is `sts:AssumeRole`.

No AWS backplane carries the fallback shape any more. `modules/aws/s3_bucket`,
`modules/aws/route53-dns-record` and `modules/aws/route53-dns-alias-record` were the last three, and
`aws_wif_no_access_key` keeps it that way.

---

## `meshstack_integration.tf` Wiring (AWS)

<!-- scorecard-checks: aws_wif_integration_env -->
### WIF pattern

```hcl
module "runner" {
  source = "github.com/meshcloud/meshstack-hub//modules/meshstack/runner-identity?ref=${var.hub.git_ref}"

  cloud               = "aws"
  runner_ref          = var.meshstack.runner_ref
  trusted_runner_refs = var.meshstack.trusted_runner_refs
  versions            = meshstack_building_block_definition.this.versions
}

module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/aws/<service>/backplane?ref=${var.hub.git_ref}"

  runner_identities = module.runner.identities
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
  argument        = jsonencode(module.runner.token_path)
}
```

The role trusts the current runner and every runner in `meshstack.trusted_runner_refs`, see
[meshstack-integration.md § Trusted runners](meshstack-integration.md#trusted-runners). The runner
lookup and the pinned `runner_ref` are the same in every cloud, see
[meshstack-integration.md § Runner identity](meshstack-integration.md#runner-identity).

The three existing modules still declare `variable "aws_oidc_provider_arn"`, with a null default and
no use, so that a caller that sets it does not fail. A new module does not declare it.

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
- [ ] Creates no `aws_iam_openid_connect_provider` — looks up the provider of each issuer in `runner_identities`
- [ ] The `runner_identities` description ends with the fixed link to the shared OIDC provider
- [ ] `runner_identities` is non-nullable
- [ ] Trust policy has one statement per identity and scopes `sub` to the subject of that identity
- [ ] Integration passes `module.runner.identities`, and gives the module `meshstack.trusted_runner_refs` and the definition's `versions`
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
