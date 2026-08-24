## Permissions

This building block requires access to the organization's billing account and a dedicated GCP project to manage notification channels.

### Authentication

The building block authenticates by **workload identity federation** — the only credential path this
backplane offers, so `workload_identity_federation` is required. The backplane creates a workload
identity pool and provider alongside the service account, grants the pool
`roles/iam.workloadIdentityUser` on it, and exports `credentials_json` as an
[external account](https://cloud.google.com/iam/docs/workload-identity-federation) document. No
long-lived secret exists anywhere in the module. `issuer`, `audience` and `subjects` must come from
`data.meshstack_integrations` — see `meshstack_integration.tf`.

There is deliberately no service account key fallback. A key is a long-lived credential to rotate,
revoke and protect, and minting one costs the applying identity `roles/iam.serviceAccountKeyAdmin`
on top of the roles below, because `roles/iam.serviceAccountAdmin` does **not** include
`iam.serviceAccountKeys.create`. Federation needs strictly fewer privileges and leaves nothing to
leak — the same reason `modules/azure/` requires a UAMI with a federated credential and forbids
client secrets.

GCP **soft-deletes** workload identity pools and providers for ~30 days and will not reissue their
identifiers in that window. `workload_identity_pool_identifier` is an input for exactly that reason:
a backplane that has to be recreated needs a fresh one, and a caller that creates and destroys
backplanes repeatedly (an e2e test) must derive a unique identifier per run. The soft-deleted pools
count against the project's pool limit while they linger.

### Roles granted to the building block's service account

The service account the backplane creates is the identity the **building block** runs as. It
receives only what the building block's own resources need:

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
| `roles/iam.serviceAccountAdmin` | `google_service_account` and its IAM policy |
| `roles/iam.workloadIdentityPoolAdmin` | `google_iam_workload_identity_pool` / `_provider` |
| `roles/resourcemanager.projectIamAdmin` | `google_project_iam_member` |

plus, on the **billing account**, permission to read and write its IAM policy for the
`google_billing_account_iam_member` grants. `roles/billing.admin` is the only predefined role that
carries `billing.accounts.setIamPolicy`; an organization-level custom role holding just
`billing.accounts.getIamPolicy` and `billing.accounts.setIamPolicy` is narrower by default, though
not a containment boundary — anything that can set the policy can grant itself the rest.

`roles/serviceusage.serviceUsageAdmin` cannot be bootstrapped by the module — enabling a service
already requires it — so it must be granted out of band before the first apply, as must the Service
Usage API itself (`gcloud services enable serviceusage.googleapis.com --project <project>`).

### APIs enabled on the backplane project

| API | For |
|------|-----|
| `iam.googleapis.com` | the service account, the pool and its provider |
| `cloudresourcemanager.googleapis.com` | the project-level IAM binding |
| `cloudbilling.googleapis.com` | the billing account IAM bindings, billed to this project as quota project |
| `sts.googleapis.com` | federated token exchange at building block run time |
| `iamcredentials.googleapis.com` | service account impersonation at run time |
| `billingbudgets.googleapis.com` | `google_billing_budget`, at run time |
| `monitoring.googleapis.com` | `google_monitoring_notification_channel`, at run time |

`monitoring.googleapis.com` is on by default in many projects, which is why its absence here went
unnoticed for a while — but a project that has never used it answers the notification channel call
with `SERVICE_DISABLED`, and the building block run then fails. The e2e target project was exactly
such a project.

## Operational notes

`google_project_service.required` sets `disable_on_destroy = false`, so destroying this backplane
leaves the APIs above enabled on the project. This is intentional: the backplane does not own the
project exclusively and may be short-lived, and disabling a project-wide API on teardown would break
anything else in that project that depends on it.

`credentials_json` is held back by a `time_sleep` of `iam_propagation_delay_seconds` (180s by
default) after the IAM grants, because GCP IAM is eventually consistent and billing-account grants
are among the slower ones. A consumer that orders a building block in the same apply therefore waits
automatically. Set it to 0 when the backplane is always provisioned well ahead of any run.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 6.12.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.9 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_billing_account_iam_member.billing_viewer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/billing_account_iam_member) | resource |
| [google_billing_account_iam_member.budget_admin](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/billing_account_iam_member) | resource |
| [google_iam_workload_identity_pool.meshstack](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool) | resource |
| [google_iam_workload_identity_pool_provider.meshstack](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool_provider) | resource |
| [google_project_iam_member.notification_channel_admin](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_service.required](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_service_account.backplane](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account_iam_binding.workload_identity](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_binding) | resource |
| [time_sleep.wait_for_iam](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [google_project.backplane](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_backplane_project_id"></a> [backplane\_project\_id](#input\_backplane\_project\_id) | The project hosting the building block backplane resources | `string` | n/a | yes |
| <a name="input_backplane_service_account_name"></a> [backplane\_service\_account\_name](#input\_backplane\_service\_account\_name) | The name of the service account to be created for the backplane | `string` | `"building-block-budget-alert"` | no |
| <a name="input_billing_account_id"></a> [billing\_account\_id](#input\_billing\_account\_id) | The billing account ID where budget permissions will be granted | `string` | n/a | yes |
| <a name="input_iam_propagation_delay_seconds"></a> [iam\_propagation\_delay\_seconds](#input\_iam\_propagation\_delay\_seconds) | Seconds to wait after granting the building block's IAM roles before publishing its credentials. GCP IAM is eventually consistent, and billing-account grants are among the slower ones. Set to 0 if the backplane is always provisioned well before any building block run. | `number` | `180` | no |
| <a name="input_workload_identity_federation"></a> [workload\_identity\_federation](#input\_workload\_identity\_federation) | Workload identity federation settings, sourced from data.meshstack\_integrations. | <pre>object({<br/>    workload_identity_pool_identifier = string<br/>    audience                          = string<br/>    issuer                            = string<br/>    subjects                          = list(string)<br/>    subject_token_file_path           = string<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_backplane_project_id"></a> [backplane\_project\_id](#output\_backplane\_project\_id) | The project hosting the building block backplane resources |
| <a name="output_billing_account_id"></a> [billing\_account\_id](#output\_billing\_account\_id) | The billing account ID where budget permissions were granted |
| <a name="output_credentials_json"></a> [credentials\_json](#output\_credentials\_json) | External account credentials for the backplane service account, for the building block to authenticate with. Contains no long-lived secret — it points the runner at its own token file. |
| <a name="output_service_account_email"></a> [service\_account\_email](#output\_service\_account\_email) | Email address of the backplane service account |
| <a name="output_service_account_id"></a> [service\_account\_id](#output\_service\_account\_id) | ID of the backplane service account |
<!-- END_TF_DOCS -->