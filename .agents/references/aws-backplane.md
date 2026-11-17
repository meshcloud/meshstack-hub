---
description: AWS backplane identity conventions for meshstack-hub modules under modules/aws/. Covers WIF (OIDC + IAM role) and cross-account (IAM user + CloudFormation StackSet) patterns, required variables/outputs, meshstack_integration.tf wiring, and the AWS backplane checklist.
---

# AWS Backplane Identity Conventions

AWS backplanes use one of two identity patterns depending on whether the building block needs to access a single account or operate across multiple accounts in an AWS Organization.

## Pattern A: Workload Identity Federation (WIF) — Single Account

Use WIF when the building block acts within a single AWS account (the backplane account or a shared services account). This is the **preferred pattern** — it eliminates long-lived credentials.

### Rationale

- **No secrets rotation**: Each run gets a short-lived JWT from an OIDC issuer; no access keys to manage.
- **BBD-scoped trust**: The IAM role trust policy is scoped to the specific building block definition UUID, preventing cross-BBD token reuse.
- **OIDC-native**: AWS supports federated OIDC identities via `aws_iam_openid_connect_provider` out of the box.
- **Shared OIDC provider**: `modules/aws/oidc-provider` creates one IAM OIDC provider per issuer in an AWS account. Every backplane in the account looks it up by the issuer URL.

<!-- scorecard-checks: aws_wif_external_oidc_provider, aws_oidc_provider_notice -->
### The shared OIDC provider

**A WIF backplane creates no IAM OIDC provider. It looks up one provider per issuer in
`runner_identities`.**

AWS allows one OIDC provider per issuer URL in an AWS account. All backplanes in the account need
the same provider for the same issuer. If each backplane created the provider, the second apply
would fail with `EntityAlreadyExists`. A destroy of the first backplane would also delete the
provider of all others.

So `modules/aws/oidc-provider` creates the provider. Apply it once per issuer in each AWS account
that hosts backplanes:

```hcl
data "meshstack_building_block_runner" "this" {
  metadata = {
    uuid = "<runner uuid>"
  }
}

module "meshstack_oidc_provider" {
  source = "github.com/meshcloud/meshstack-hub//modules/aws/oidc-provider?ref=main"

  workload_identity_federation = {
    issuer    = data.meshstack_building_block_runner.this.spec.workload_identity_federation.issuer
    audiences = [data.meshstack_building_block_runner.this.spec.workload_identity_federation.aws.audience]
  }
}
```

`audiences` usually has one value, the AWS audience of the runner. It is a list because AWS allows
several audiences per provider. Two runners whose tokens come from the same issuer share the
provider, so add the audience of both. The
module reads the thumbprint from the TLS certificate chain of the issuer. So the machine that
applies the module must reach the issuer URL.

Each issuer needs its own OIDC provider. The tokens of another runner can come from another issuer.
Then apply the module once more with the `issuer` and `aws.audience` of that runner. Also set
`meshstack.runner_ref` to that runner in every hub module whose definition uses it.

Two runners can get their tokens from different issuers. For example, the meshStack identity
provider issues the tokens of one runner. A Kubernetes cluster issues the tokens of another.
One provider ARN identifies the provider of one issuer. So the backplane looks up one IAM OIDC
provider per issuer in `runner_identities`. It uses `data "aws_iam_openid_connect_provider"` with
the issuer as `url`. [Trusted runners](meshstack-integration.md#trusted-runners) explains when
`runner_identities` has more than one entry.

- Create the provider of every issuer before you plan the backplane. Otherwise the lookup fails the
  plan. So apply `modules/aws/oidc-provider` first, from its own root module or with `-target`.
- Do not set `depends_on` on the hub module. It makes the issuer unknown during the plan, and the
  lookup then fails with "Invalid for_each argument".
- The lookup needs `iam:ListOpenIDConnectProviders` and `iam:GetOpenIDConnectProvider`.
- A caller can use a backplane without the `meshstack_integration.tf` of its module. This caller
  passes one identity in `workload_identity_federation` and the provider ARN in `oidc_provider_arn`.
  The backplane then looks up no provider for that identity.

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
then find it by its issuer.

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

# AWS has one OIDC provider per issuer in an account, so the issuer URL identifies the provider.
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
      # Skip an entry without a subject. No version of the definition uses that runner.
      if identity.subject != null
    ],
  )
}

data "aws_iam_policy_document" "workload_identity_federation" {
  version = "2012-10-17"

  lifecycle {
    precondition {
      condition     = length(local.trusted_identities) > 0
      error_message = "The trust policy of the role would be empty. The backplane input runner_identities has no entry with a subject, and the input workload_identity_federation is not set. A subject is null when no version of the building block definition uses that runner."
    }

    precondition {
      condition     = var.workload_identity_federation == null || var.oidc_provider_arn != null
      error_message = "Set oidc_provider_arn together with workload_identity_federation."
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
  AWS lets a run assume the role when its token matches one of these entries.
  Pass the output `identities` of modules/meshstack/runner-identity.
  The backplane skips an entry with a null subject, but still looks up the provider of its issuer.
  Create the IAM OIDC provider of each issuer in this AWS account first.
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
  One more entry like those in `runner_identities`, for a caller without modules/meshstack/runner-identity. Set `oidc_provider_arn` with it.
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

The scorecard requires this exact line in the `runner_identities` description. Without the
provider, the lookup fails the plan. The link shows the platform engineer what to apply first.

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

Runs on the current runner and on every runner in `meshstack.trusted_runner_refs` can assume the
role. See
[meshstack-integration.md § Trusted runners](meshstack-integration.md#trusted-runners). The runner
lookup and the pinned `runner_ref` are the same in every cloud, see
[meshstack-integration.md § Runner identity](meshstack-integration.md#runner-identity).

`aws/s3_bucket`, `aws/route53-dns-record` and `aws/route53-dns-alias-record` declare an unused
`variable "aws_oidc_provider_arn"`, so that a caller that sets it does not fail. A new module does
not declare it.

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
- [ ] The `runner_identities` description contains the link line to the shared OIDC provider
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
