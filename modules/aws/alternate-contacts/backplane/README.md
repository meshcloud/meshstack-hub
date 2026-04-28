---
name: AWS Alternate Contacts Backplane
supportedPlatforms:
- aws
description: |
  Backplane infrastructure for the AWS Alternate Contacts building block.
---

This module sets up the IAM user and StackSet-based role deployment needed to manage alternate contacts on AWS accounts in your organization.

It creates:

1. An **IAM User** in your backplane account with permission to assume a service role in target accounts.
2. A **CloudFormation StackSet** deployed to the specified OUs that creates a service role in each target account with the necessary `account:*AlternateContact` permissions.

## Usage

```hcl
module "alternate_contacts_backplane" {
  source = "./modules/aws/alternate-contacts/backplane"

  building_block_target_ou_ids = ["ou-xxxx-xxxxxxxx"]

  providers = {
    aws.management = aws.management
    aws.backplane  = aws.backplane
  }
}
```

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
| <a name="input_backplane_user_name"></a> [backplane\_user\_name](#input\_backplane\_user\_name) | n/a | `string` | `"building-block-alternate-contacts"` | no |
| <a name="input_building_block_target_account_access_role_name"></a> [building\_block\_target\_account\_access\_role\_name](#input\_building\_block\_target\_account\_access\_role\_name) | Name of the role that the backplane user will assume in the target account | `string` | `"building-block-alternate-contacts"` | no |
| <a name="input_building_block_target_ou_ids"></a> [building\_block\_target\_ou\_ids](#input\_building\_block\_target\_ou\_ids) | List of OUs that the building block can be deployed to. Accounts in these OUs will receive the building\_block\_backplane\_account\_access\_role | `set(string)` | n/a | yes |
| <a name="input_stackset_region"></a> [stackset\_region](#input\_stackset\_region) | AWS region to deploy the StackSet instances in | `string` | `"eu-central-1"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_aws_access_key_id"></a> [aws\_access\_key\_id](#output\_aws\_access\_key\_id) | Access key for the IAM user that can set alternate contacts |
| <a name="output_aws_secret_access_key"></a> [aws\_secret\_access\_key](#output\_aws\_secret\_access\_key) | Secret key for the IAM user that can set alternate contacts |
| <a name="output_role_name"></a> [role\_name](#output\_role\_name) | Name of the IAM role assumed in target accounts to set alternate contacts |
<!-- END_TF_DOCS -->
