# AWS Budget Alert Backplane

This Terraform module provides the necessary IAM roles and permissions to enable the deployment of AWS Budget Alert building blocks to target accounts in specific OUs.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudformation_stack_set.permissions_in_target_accounts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_set) | resource |
| [aws_cloudformation_stack_set_instance.permissions_in_target_accounts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_set_instance) | resource |
| [aws_iam_access_key.backplane](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_access_key) | resource |
| [aws_iam_user.backplane](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user) | resource |
| [aws_iam_user_policy.assume_roles](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user_policy) | resource |
| [aws_iam_policy_document.building_block_service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_backplane_user_name"></a> [backplane\_user\_name](#input\_backplane\_user\_name) | n/a | `string` | `"building-block-budget-alert"` | no |
| <a name="input_building_block_target_account_access_role_name"></a> [building\_block\_target\_account\_access\_role\_name](#input\_building\_block\_target\_account\_access\_role\_name) | Name of the role that the backplane user will assume in the target account | `string` | `"building-block-budget-alert"` | no |
| <a name="input_building_block_target_ou_ids"></a> [building\_block\_target\_ou\_ids](#input\_building\_block\_target\_ou\_ids) | List of OUs that the building block can be deployed to. Accounts in these OUs will receive the building\_block\_backplane\_account\_access\_role | `set(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_aws_access_key_id"></a> [aws\_access\_key\_id](#output\_aws\_access\_key\_id) | Access key for the IAM role that can deploy budget alerts |
| <a name="output_aws_secret_access_key"></a> [aws\_secret\_access\_key](#output\_aws\_secret\_access\_key) | Secret key for the IAM role that can deploy budget alerts |
| <a name="output_role_name"></a> [role\_name](#output\_role\_name) | ARN of the IAM role that can deploy budget alerts |
<!-- END_TF_DOCS -->