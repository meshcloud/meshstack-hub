---
name: GCP Project Budget Alert
supportedPlatforms:
  - gcp
description: |
  Sets up budget alerts for a GCP project to monitor spending and prevent cost overruns.
---

This buildingblock deploys a GCP budget alert to monitor project spending and send notifications when budget thresholds are exceeded.

## Permissions

Please reference the [backplane implementation](../backplane/) for the required permissions to deploy this building block.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | 6.12.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_billing_budget.budget](https://registry.terraform.io/providers/hashicorp/google/6.12.0/docs/resources/billing_budget) | resource |
| [google_monitoring_notification_channel.notification_channel](https://registry.terraform.io/providers/hashicorp/google/6.12.0/docs/resources/monitoring_notification_channel) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alert_thresholds_yaml"></a> [alert\_thresholds\_yaml](#input\_alert\_thresholds\_yaml) | YAML string defining alert thresholds with fields threshold\_percent and spend\_basis | `string` | `"- percent: 80\n  basis: ACTUAL\n- percent: 100\n  basis: FORECASTED\n"` | no |
| <a name="input_backplane_project_id"></a> [backplane\_project\_id](#input\_backplane\_project\_id) | The project ID where the backplane resources will be created | `string` | n/a | yes |
| <a name="input_billing_account_id"></a> [billing\_account\_id](#input\_billing\_account\_id) | The ID of the billing account to which the budget will be applied | `string` | n/a | yes |
| <a name="input_budget_currency"></a> [budget\_currency](#input\_budget\_currency) | The currency for the budget amount, e.g., EUR | `string` | `"EUR"` | no |
| <a name="input_budget_name"></a> [budget\_name](#input\_budget\_name) | Display name for the budget | `string` | n/a | yes |
| <a name="input_contact_email"></a> [contact\_email](#input\_contact\_email) | email address to receive budget alerts | `string` | n/a | yes |
| <a name="input_monthly_budget_amount"></a> [monthly\_budget\_amount](#input\_monthly\_budget\_amount) | The budget amount in the project's billing currency | `number` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The GCP project ID where the budget will be created | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_budget_id"></a> [budget\_id](#output\_budget\_id) | The ID of the created budget |
<!-- END_TF_DOCS -->