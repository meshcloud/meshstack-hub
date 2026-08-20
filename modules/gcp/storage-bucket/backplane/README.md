# GCP Storage Bucket Backplane

This module prepares the GCP project for the GCP Storage Bucket building block: it enables the APIs
the building block depends on, creates the service account the building block runs as, and — on the
workload identity path — the workload identity pool and provider that let the meshStack building
block runner federate into that service account.

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
    subjects = [
      "system:serviceaccount:your-namespace:your-service-account-name",
      "system:serviceaccount:your-namespace:another-service-account",
    ]
    subject_token_file_path = "/path/to/your/token/file"
  } # Optional, if not provided, a service account key will be created instead
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

When `workload_identity_federation` is configured, the module grants access to the entire workload identity pool at the IAM level, then uses attribute conditions at the provider level to restrict which identities can actually authenticate.

### Subject Matching

The module supports both exact matching and partial matching for subjects:

**Exact matching** - Grant access to specific subjects:
```hcl
workload_identity_federation = {
  issuer = "https://your-oidc-issuer"
  subjects = [
    "system:serviceaccount:namespace1:service-account-1",
    "system:serviceaccount:namespace1:service-account-2",
  ]
}
```

**Partial matching** - Use `startsWith()` to match multiple subjects with a common prefix. Note: The module doesn't use special syntax for this; instead, pass the prefix pattern as-is and it will be matched using CEL's `startsWith()` function:

```hcl
workload_identity_federation = {
  issuer = "https://your-oidc-issuer"
  subjects = [
    "system:serviceaccount:namespace1:",  # Matches all service accounts in namespace1
  ]
}
```

This configuration will accept any subject that starts with `system:serviceaccount:namespace1:`, allowing all service accounts in that namespace to authenticate without listing each one individually.

**How it works:**
- IAM binding grants access to the entire workload identity pool (`principalSet://iam.googleapis.com/.../pools/POOL_ID/*`)
- Attribute conditions in the provider filter which tokens are accepted based on the `google.subject` claim
- Subjects are evaluated as exact matches first, then partial matches via `startsWith()` checking

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
| [google_service_account_key.buildingblock_storage_key](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_key) | resource |
| [time_sleep.wait_for_iam](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_iam_propagation_delay_seconds"></a> [iam\_propagation\_delay\_seconds](#input\_iam\_propagation\_delay\_seconds) | Seconds to wait after granting the building block's IAM roles before publishing its credentials. GCP IAM is eventually consistent, and Google's guidance is to allow two to seven minutes before retrying a denied impersonation. Set to 0 if the backplane is always provisioned well before any building block run. | `number` | `180` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The GCP project ID | `string` | n/a | yes |
| <a name="input_service_account_id"></a> [service\_account\_id](#input\_service\_account\_id) | The ID of the service account to create | `string` | `"buildingblock-storage-sa"` | no |
| <a name="input_workload_identity_federation"></a> [workload\_identity\_federation](#input\_workload\_identity\_federation) | Configuration for workload identity federation. Supports multiple subjects with exact matching and partial matching using startsWith(). | <pre>object({<br/>    workload_identity_pool_identifier = string       // Identifier for the workload identity pool<br/>    audience                          = string       // Audience for the OIDC tokens<br/>    issuer                            = string       // OIDC issuer URL<br/>    subjects                          = list(string) // Subjects for workload identity federation - can use exact matches or startsWith patterns<br/>    subject_token_file_path           = string       // Path to the file containing the OIDC token<br/>  })</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_credentials_json"></a> [credentials\_json](#output\_credentials\_json) | n/a |
| <a name="output_service_account_email"></a> [service\_account\_email](#output\_service\_account\_email) | Email of the service account |
| <a name="output_workload_identity_pool_name"></a> [workload\_identity\_pool\_name](#output\_workload\_identity\_pool\_name) | Name of the workload identity pool |
| <a name="output_workload_identity_provider_name"></a> [workload\_identity\_provider\_name](#output\_workload\_identity\_provider\_name) | Name of the workload identity provider |
<!-- END_TF_DOCS -->