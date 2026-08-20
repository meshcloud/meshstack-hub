## Permissions

This building block requires access to the organization's billing account and a dedicated GCP project to manage notification channels.

### Roles granted to the building block's service account

The backplane creates a service account and exports its key as `credentials_json`; that is the
identity the **building block** runs as. It receives only what the building block's own resources
need:

| Role | Scope | For |
|------|-------|-----|
| `roles/billing.costsManager` | billing account | `google_billing_budget` |
| `roles/billing.viewer` | billing account | reading billing data for the budget |
| `roles/monitoring.notificationChannelEditor` | backplane project | `google_monitoring_notification_channel` |

The building block never enables a service, so it is deliberately **not** granted
`roles/serviceusage.serviceUsageAdmin` — that would let a tenant-facing identity enable arbitrary
APIs on the project for no benefit.

### Roles required by the identity applying this backplane

The platform engineer or CI principal that applies this module needs, on the backplane project:

| Role | For |
|------|-----|
| `roles/serviceusage.serviceUsageAdmin` | `google_project_service` |
| `roles/iam.serviceAccountAdmin` | `google_service_account` and its key |
| `roles/resourcemanager.projectIamAdmin` | `google_project_iam_member` |

plus `roles/billing.admin` (or an equivalent) on the billing account for the
`google_billing_account_iam_member` grants.

`roles/serviceusage.serviceUsageAdmin` cannot be bootstrapped by the module — enabling a service
already requires it — so it must be granted out of band before the first apply, as must the Service
Usage API itself (`gcloud services enable serviceusage.googleapis.com --project <project>`).

## Operational notes

`google_project_service.billingbudgets` sets `disable_on_destroy = false`, so destroying this
backplane leaves `billingbudgets.googleapis.com` enabled on the project. This is intentional: the
backplane does not own the project exclusively and may be short-lived, and disabling a project-wide
API on teardown would break anything else in that project that depends on it.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_google"></a> [google](#requirement\_google) | 6.12.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_billing_account_iam_member.billing_viewer](https://registry.terraform.io/providers/hashicorp/google/6.12.0/docs/resources/billing_account_iam_member) | resource |
| [google_billing_account_iam_member.budget_admin](https://registry.terraform.io/providers/hashicorp/google/6.12.0/docs/resources/billing_account_iam_member) | resource |
| [google_project_iam_member.notification_channel_admin](https://registry.terraform.io/providers/hashicorp/google/6.12.0/docs/resources/project_iam_member) | resource |
| [google_project_service.billingbudgets](https://registry.terraform.io/providers/hashicorp/google/6.12.0/docs/resources/project_service) | resource |
| [google_service_account.backplane](https://registry.terraform.io/providers/hashicorp/google/6.12.0/docs/resources/service_account) | resource |
| [google_service_account_key.backplane](https://registry.terraform.io/providers/hashicorp/google/6.12.0/docs/resources/service_account_key) | resource |
| [google_project.backplane](https://registry.terraform.io/providers/hashicorp/google/6.12.0/docs/data-sources/project) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_backplane_project_id"></a> [backplane\_project\_id](#input\_backplane\_project\_id) | The project hosting the building block backplane resources | `string` | n/a | yes |
| <a name="input_backplane_service_account_name"></a> [backplane\_service\_account\_name](#input\_backplane\_service\_account\_name) | The name of the service account to be created for the backplane | `string` | `"building-block-budget-alert"` | no |
| <a name="input_billing_account_id"></a> [billing\_account\_id](#input\_billing\_account\_id) | The billing account ID where budget permissions will be granted | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_backplane_project_id"></a> [backplane\_project\_id](#output\_backplane\_project\_id) | The project hosting the building block backplane resources |
| <a name="output_billing_account_id"></a> [billing\_account\_id](#output\_billing\_account\_id) | The billing account ID where budget permissions were granted |
| <a name="output_credentials_json"></a> [credentials\_json](#output\_credentials\_json) | The JSON credentials for the backplane service account |
| <a name="output_service_account_email"></a> [service\_account\_email](#output\_service\_account\_email) | Email address of the backplane service account |
| <a name="output_service_account_id"></a> [service\_account\_id](#output\_service\_account\_id) | ID of the backplane service account |
<!-- END_TF_DOCS -->