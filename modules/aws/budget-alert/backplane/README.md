# AWS Budget Alert Backplane

Provides the two identities the AWS Budget Alert building block needs:

- an IAM role the building block runner federates into via OIDC — the backplane holds no long-lived
  credential, see [aws-backplane.md](../../../../.agents/references/aws-backplane.md)
- the IAM role that federated role assumes in the account the budget is created in, which is the
  only place `budgets:*` is granted

A budget belongs to the account whose spend it tracks, so the second role has to exist in every
account the building block can be ordered for. How it gets there depends on
`building_block_target_ou_ids`:

| `building_block_target_ou_ids` | Deployment | How the target role is created |
|---|---|---|
| one or more OU IDs | AWS Organization | A `SERVICE_MANAGED` CloudFormation StackSet deploys it to every account in those OUs, and to accounts that join later. Needs trusted access for StackSets enabled and the `aws.management` provider pointed at the management account (or a delegated admin). |
| empty set | single account | The backplane creates it next to itself — the account hosting the backplane is also the account receiving the budget. `aws.management` is then unused, but still has to be configured. |

Apply the default provider against the account hosting the backplane. This is typically a dedicated
automation account, not the organization's management account: the only permission the federated
role holds there is `sts:AssumeRole` on the target role name.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0, < 6.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudformation_stack_set.permissions_in_target_accounts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_set) | resource |
| [aws_cloudformation_stack_set_instance.permissions_in_target_accounts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_set_instance) | resource |
| [aws_iam_policy.assume_target_account_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.target_account](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.backplane](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.target_account](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.assume_target_account_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.target_account](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.assume_target_account_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.target_account_role_trust](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.workload_identity_federation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_building_block_target_account_access_role_name"></a> [building\_block\_target\_account\_access\_role\_name](#input\_building\_block\_target\_account\_access\_role\_name) | Name of the role the backplane assumes in the account the budget is created in. | `string` | `"building-block-budget-alert"` | no |
| <a name="input_building_block_target_ou_ids"></a> [building\_block\_target\_ou\_ids](#input\_building\_block\_target\_ou\_ids) | AWS OU IDs whose accounts receive the target role via StackSet. Accounts outside these OUs cannot<br/>be reached. Pass an empty set for a single-account deployment, where the backplane creates the<br/>target role in its own account instead. | `set(string)` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name for the federated backplane IAM role and policy (suffixed -role and -assume-roles). | `string` | `"budget-alert"` | no |
| <a name="input_oidc_provider_arn"></a> [oidc\_provider\_arn](#input\_oidc\_provider\_arn) | ARN of the IAM OIDC provider for the meshStack runner WIF token issuer in this AWS account.<br/>See .agents/references/aws-backplane.md#the-shared-oidc-provider | `string` | n/a | yes |
| <a name="input_stackset_region"></a> [stackset\_region](#input\_stackset\_region) | AWS region the StackSet instance is deployed in. IAM is global, so this only decides where CloudFormation tracks the stacks. | `string` | `"eu-central-1"` | no |
| <a name="input_workload_identity_federation"></a> [workload\_identity\_federation](#input\_workload\_identity\_federation) | Trusted identity provider from meshStack that the building block runner federates into.<br/>Supports multiple subjects and wildcard patterns (e.g., 'system:serviceaccount:namespace:*'). | <pre>object({<br/>    issuer   = string<br/>    audience = string<br/>    subjects = list(string)<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_role_name"></a> [role\_name](#output\_role\_name) | Name of the IAM role the building block assumes in the account the budget is created in. |
| <a name="output_workload_identity_federation_role"></a> [workload\_identity\_federation\_role](#output\_workload\_identity\_federation\_role) | ARN of the IAM role the building block runner assumes via workload identity federation. |
<!-- END_TF_DOCS -->
