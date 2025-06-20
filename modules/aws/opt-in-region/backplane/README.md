<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | 5.77.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_access_key.backplane](https://registry.terraform.io/providers/hashicorp/aws/5.77.0/docs/resources/iam_access_key) | resource |
| [aws_iam_role.backplane](https://registry.terraform.io/providers/hashicorp/aws/5.77.0/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.backplane](https://registry.terraform.io/providers/hashicorp/aws/5.77.0/docs/resources/iam_role_policy) | resource |
| [aws_iam_user.backplane](https://registry.terraform.io/providers/hashicorp/aws/5.77.0/docs/resources/iam_user) | resource |
| [aws_iam_user_policy.assume_roles](https://registry.terraform.io/providers/hashicorp/aws/5.77.0/docs/resources/iam_user_policy) | resource |
| [aws_iam_policy_document.backplane](https://registry.terraform.io/providers/hashicorp/aws/5.77.0/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.building_block_service](https://registry.terraform.io/providers/hashicorp/aws/5.77.0/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.trust_policy](https://registry.terraform.io/providers/hashicorp/aws/5.77.0/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_backplane_role_name"></a> [backplane\_role\_name](#input\_backplane\_role\_name) | Name of the role that the backplane user will assume in the management account to manage opt-in regions | `string` | `"building-block-opt-in-region"` | no |
| <a name="input_backplane_user_name"></a> [backplane\_user\_name](#input\_backplane\_user\_name) | n/a | `string` | `"building-block-opt-in-region"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_aws_access_key_id"></a> [aws\_access\_key\_id](#output\_aws\_access\_key\_id) | Access key for the IAM role that can deploy the building block |
| <a name="output_aws_secret_access_key"></a> [aws\_secret\_access\_key](#output\_aws\_secret\_access\_key) | Secret key for the IAM role that can deploy the building block |
| <a name="output_backplane_role_arn"></a> [backplane\_role\_arn](#output\_backplane\_role\_arn) | ARN of the IAM role that can deploy the building block |
<!-- END_TF_DOCS -->