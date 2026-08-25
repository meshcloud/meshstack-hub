# GCP Storage Bucket Backplane

This module prepares the GCP project for the GCP Storage Bucket building block: it enables the APIs
the building block depends on, creates the service account the building block runs as, and creates
the workload identity pool and provider that let the meshStack building block runner federate into
that service account.

## Permissions

The identity that applies this module (a platform engineer or a CI principal, **not** the building
block's own service account) needs the following on `var.project_id`:

| Role | What it is for |
|---|---|
| `roles/serviceusage.serviceUsageAdmin` | enable the project APIs listed below |
| `roles/iam.workloadIdentityPoolAdmin` | create the workload identity pool and its OIDC provider |
| `roles/iam.serviceAccountAdmin` | create the building block service account and set its IAM policy |
| `roles/resourcemanager.projectIamAdmin` | grant that service account `roles/storage.admin` |

`roles/owner` covers all four. `serviceusage.serviceUsageAdmin` cannot be self-granted by this
module — enabling a service already requires it — so it has to be in place before the first apply.

The **Service Usage API must also be enabled on the project already**. This module cannot turn it on,
because it is the API that does the enabling, and a project where it is off fails on the read before
any enable is attempted (`Failed to list enabled services … reason: SERVICE_DISABLED`). It is a
one-time step for the project owner:

```sh
gcloud services enable serviceusage.googleapis.com --project <project>
```

The module deliberately does **not** grant `roles/serviceusage.serviceUsageAdmin` to the building
block's service account: the building block only creates buckets and never enables a service, so
the grant would widen the per-tenant automation principal for no functional reason.

### APIs enabled

`iam`, `cloudresourcemanager`, `sts`, `iamcredentials` and `storage`. All are enabled with
`disable_on_destroy = false` — destroying this backplane must not switch project-wide APIs off
under other tenants of the same project.

If your organization enables APIs centrally and will not grant this module
`serviceusage.serviceUsageAdmin`, adopt the already-enabled services into state
(`tofu import 'google_project_service.required["storage.googleapis.com"]' <project>/storage.googleapis.com`,
and so on) before applying.

## Usage

This module expects a configured `google` provider from its caller — it deliberately declares no
`provider` block of its own, so callers can wrap it in a module call that uses `count`, `for_each`
or `depends_on`.

```hcl
module "gcp_storage_bucket_backplane" {
  source = "git::https://github.com/meshcloud/meshstack-hub.git//modules/gcp/storage-bucket/backplane"

  project_id         = "your-gcp-project-id"
  service_account_id = "your-service-account-id" # Optional, defaults to "buildingblock-storage-sa"
  workload_identity_federation = {
    workload_identity_pool_identifier = "your-pool-identifier"
    audience                          = "your-audience"
    issuer                            = "https://your-oidc-issuer"
    subject_token_file_path           = "/path/to/your/token/file"
  }
  workload_identity_subjects = [
    "system:serviceaccount:your-namespace:workspace.your-workspace.buildingblockdefinition.your-bbd-uuid",
  ]
}
```

## IAM propagation

Applying this backplane takes about three minutes longer than the resources alone suggest. That is
deliberate: GCP IAM is eventually consistent, and Google's guidance is to allow two to seven minutes
after adding a `roles/iam.workloadIdentityUser` binding before a denied impersonation will start
working. The `credentials_json` output waits on `time_sleep.wait_for_iam`, so a caller that creates a
building block definition from it and orders a building block immediately does not race the grant.

Without the wait, the building block run fails in a way that looks like a broken pool but is not —
the token exchange succeeds and only the impersonation is refused:

```
oauth2/google: status code 403: Permission 'iam.serviceAccounts.getAccessToken' denied on
resource (or it may not exist). ... "reason": "IAM_PERMISSION_DENIED"
```

Tune or disable the wait with `iam_propagation_delay_seconds` (set it to `0` if you always provision
the backplane well before any building block runs).

## Workload Identity Federation

> **Operational note — pool identifiers are not immediately reusable.** GCP soft-deletes workload
> identity pools and providers and keeps them for ~30 days, during which their identifiers cannot
> be claimed again. Destroying and re-applying this backplane with the same
> `workload_identity_pool_identifier` therefore fails until the retention window elapses. Pick a
> fresh identifier per deployment if you need to recreate the backplane, and be aware that
> soft-deleted pools still count towards the project's workload identity pool limit.

### Subject matching is exact

The provider's `attribute_condition` compares `google.subject` for **equality** against each entry of
`workload_identity_subjects`. Pass the complete `sub` claim of the token you want accepted, not a
prefix:

```hcl
workload_identity_subjects = [
  "system:serviceaccount:<runner-namespace>:workspace.<workspace-id>.buildingblockdefinition.<bbd-uuid>",
]
```

`meshstack_integration.tf` derives exactly this value, so the pool admits the runner of **one**
building block definition. Prefix matching is deliberately not supported: the building block runner
names its per-run service account `workspace.<workspace>.buildingblockdefinition.<bbd-uuid>`, so a
prefix that stopped at `buildingblockdefinition` would let every other building block definition in
the same workspace federate into this service account.

The `roles/iam.workloadIdentityUser` binding on the service account is pool-wide
(`principalSet://iam.googleapis.com/.../workloadIdentityPools/POOL_ID/*`). That is not a wider grant
than the condition above: the pool holds a single provider, and that provider accepts a single
subject, so the set has exactly one member. Naming the subject in the binding as well would make the
binding depend on the building block definition uuid — and `credentials_json` waits on that binding
for IAM propagation, which would close a dependency cycle.

### Why the subjects are their own variable

The subjects name the building block definition, and that same definition carries `credentials_json`
as an input. Nothing on the credential path may therefore depend on them. OpenTofu tracks module
input dependencies **per variable**, not per attribute, so a `subjects` field inside
`workload_identity_federation` would taint every resource that reads any other field of that object —
including the pool, the `roles/iam.workloadIdentityUser` binding, and through the propagation wait,
the credentials themselves. Keeping the subjects in `workload_identity_subjects` confines the
dependency to the one resource that needs it, the pool provider.

For the same reason `credentials_json` builds its `audience` from the project number and the pool
identifier
(`//iam.googleapis.com/projects/<number>/locations/global/workloadIdentityPools/<pool>/providers/<pool>`)
instead of reading `google_iam_workload_identity_pool_provider.meshstack.name` — reading the
attribute back would put the pool provider, the one subject-dependent resource, on the credential
path.

`tofu validate` on this module alone does not surface either cycle. Only a root that wires
`meshstack_integration.tf` against a local `backplane/` does.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 7.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.9 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_iam_workload_identity_pool.meshstack](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool) | resource |
| [google_iam_workload_identity_pool_provider.meshstack](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool_provider) | resource |
| [google_project_iam_member.storage_admin](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_service.required](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_service_account.buildingblock_storage_sa](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account_iam_binding.workload_identity_binding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_binding) | resource |
| [time_sleep.wait_for_iam](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [google_project.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_iam_propagation_delay_seconds"></a> [iam\_propagation\_delay\_seconds](#input\_iam\_propagation\_delay\_seconds) | Seconds to wait after granting the building block's IAM roles before publishing its credentials. GCP IAM is eventually consistent, and Google's guidance is to allow two to seven minutes before retrying a denied impersonation. Set to 0 if the backplane is always provisioned well before any building block run. | `number` | `180` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The GCP project ID | `string` | n/a | yes |
| <a name="input_service_account_id"></a> [service\_account\_id](#input\_service\_account\_id) | The ID of the service account to create | `string` | `"buildingblock-storage-sa"` | no |
| <a name="input_workload_identity_federation"></a> [workload\_identity\_federation](#input\_workload\_identity\_federation) | Workload identity federation settings, sourced from data.meshstack\_integrations. The accepted subjects are a separate variable — see workload\_identity\_subjects. | <pre>object({<br/>    workload_identity_pool_identifier = string // Identifier for the workload identity pool<br/>    audience                          = string // Audience for the OIDC tokens<br/>    issuer                            = string // OIDC issuer URL<br/>    subject_token_file_path           = string // Path to the file containing the OIDC token<br/>  })</pre> | n/a | yes |
| <a name="input_workload_identity_subjects"></a> [workload\_identity\_subjects](#input\_workload\_identity\_subjects) | Full `sub` claims of the OIDC tokens the pool provider accepts, matched exactly. Each must name the building block definition that authenticates with these credentials. | `list(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_credentials_json"></a> [credentials\_json](#output\_credentials\_json) | External account credentials for the building block's service account. Points the runner at its own OIDC token file, which it exchanges for a short-lived access token. |
| <a name="output_service_account_email"></a> [service\_account\_email](#output\_service\_account\_email) | Email of the service account |
| <a name="output_workload_identity_pool_name"></a> [workload\_identity\_pool\_name](#output\_workload\_identity\_pool\_name) | Name of the workload identity pool |
| <a name="output_workload_identity_provider_name"></a> [workload\_identity\_provider\_name](#output\_workload\_identity\_provider\_name) | Name of the workload identity provider |
<!-- END_TF_DOCS -->