---
name: "GCP Budget Alert"
summary: |
  Deploy a GCP budget alert to monitor and alert on project spending.

  This buildingblock creates a budget for a GCP project with configurable alert thresholds.
  It monitors actual spend and forecasted spend against the budget amount, sending notifications
  when thresholds are exceeded.

  The module includes:
  - Budget resource with configurable amount and time period
  - Alert thresholds at 80% (warning) and 100% (critical)
  - Integration with notification channels for alerting
  - Support for both actual and forecasted spend monitoring

compliance: []
---

# GCP Budget Alert

This buildingblock deploys a GCP budget alert to monitor project spending and send notifications when budget thresholds are exceeded.

## Usage

Configure the budget alert in your `terragrunt.hcl`:

```hcl
inputs = {
  project_id    = "my-gcp-project"
  budget_amount = 1000
  alert_thresholds = {
    warning  = 0.8   # Alert at 80%
    critical = 1.0   # Alert at 100%
  }
}
```

## Features

- **Budget Monitoring**: Tracks actual and forecasted spend against budget
- **Configurable Thresholds**: Set warning and critical alert levels
- **Notification Integration**: Alerts via configured notification channels
- **Time Period Support**: Monthly budget cycles with calendar month alignment

## Requirements

- GCP project with billing enabled
- Appropriate IAM permissions for budget management
- Notification channels configured in the target project

## Alert Behavior

- **Warning Alert (80%)**: Sent when actual or forecasted spend reaches 80% of budget
- **Critical Alert (100%)**: Sent when actual or forecasted spend reaches 100% of budget
- **Forecasted Alerts**: Help prevent budget overruns by alerting on projected spend

The budget resets at the beginning of each calendar month.

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