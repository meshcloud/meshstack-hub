---
name: AWS Budget Alert
supportedPlatforms:
- aws
description: |
  Sets up budget alerts for an AWS account to monitor spending and prevent cost overruns.
---

This Terraform module provisions AWS Budget Alerts to help you monitor and control your cloud spending.

## Permissions

Please reference the [backplane implementation](../backplane/) for the required permissions to deploy this building block.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | ~> 0.11.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_budgets_budget.account_budget](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/budgets_budget) | resource |
| [time_static.start_date](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/static) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | target account id where the budget alert should be created | `string` | n/a | yes |
| <a name="input_actual_threshold_percent"></a> [actual\_threshold\_percent](#input\_actual\_threshold\_percent) | The precise percentage of the monthly budget at which you wish to activate the alert upon reaching. E.g. '15' for 15% or '120' for 120% | `number` | `80` | no |
| <a name="input_assume_role_name"></a> [assume\_role\_name](#input\_assume\_role\_name) | The name of the role to assume in target account identified by account\_id | `string` | n/a | yes |
| <a name="input_aws_partition"></a> [aws\_partition](#input\_aws\_partition) | The AWS partition to use. e.g. aws, aws-cn, aws-us-gov | `string` | `"aws"` | no |
| <a name="input_budget_name"></a> [budget\_name](#input\_budget\_name) | Name of the budget alert rule | `string` | `"budget_alert"` | no |
| <a name="input_contact_emails"></a> [contact\_emails](#input\_contact\_emails) | Comma-separated list of emails of the users who should receive the Budget alert. e.g. 'foo@example.com, bar@example.com' | `string` | n/a | yes |
| <a name="input_forecasted_threshold_percent"></a> [forecasted\_threshold\_percent](#input\_forecasted\_threshold\_percent) | The forecasted percentage of the monthly budget at which you wish to activate the alert upon reaching. E.g. '15' for 15% or '120' for 120% | `number` | `100` | no |
| <a name="input_monthly_budget_amount"></a> [monthly\_budget\_amount](#input\_monthly\_budget\_amount) | Set the monthly budget for this account in USD. | `number` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_budget_amount"></a> [budget\_amount](#output\_budget\_amount) | The amount of the budget |
| <a name="output_budget_id"></a> [budget\_id](#output\_budget\_id) | The ID of the budget |
| <a name="output_budget_name"></a> [budget\_name](#output\_budget\_name) | The name of the budget |
<!-- END_TF_DOCS -->
