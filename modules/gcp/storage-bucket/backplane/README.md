# GCP Storage Bucket Backplane

This module provisions the necessary IAM resources for the GCP Storage Bucket building block.

## Usage

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

## Workload Identity Federation

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
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 7.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_iam_workload_identity_pool.meshstack](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool) | resource |
| [google_iam_workload_identity_pool_provider.meshstack](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool_provider) | resource |
| [google_project_iam_member.storage_admin](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_service_account.buildingblock_storage_sa](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account_iam_binding.workload_identity_binding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_binding) | resource |
| [google_service_account_key.buildingblock_storage_key](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_key) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The GCP project ID | `string` | n/a | yes |
| <a name="input_service_account_id"></a> [service\_account\_id](#input\_service\_account\_id) | The ID of the service account to create | `string` | `"buildingblock-storage-sa"` | no |
| <a name="input_workload_identity_federation"></a> [workload\_identity\_federation](#input\_workload\_identity\_federation) | Configuration for workload identity federation. Supports multiple subjects with exact matching and partial matching using startsWith(). | <pre>object({<br>    workload_identity_pool_identifier = string       // Identifier for the workload identity pool<br>    audience                          = string       // Audience for the OIDC tokens<br>    issuer                            = string       // OIDC issuer URL<br>    subjects                          = list(string) // Subjects for workload identity federation - can use exact matches or startsWith patterns<br>    subject_token_file_path           = string       // Path to the file containing the OIDC token<br>  })</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_credentials_json"></a> [credentials\_json](#output\_credentials\_json) | n/a |
| <a name="output_service_account_email"></a> [service\_account\_email](#output\_service\_account\_email) | Email of the service account |
| <a name="output_workload_identity_pool_name"></a> [workload\_identity\_pool\_name](#output\_workload\_identity\_pool\_name) | Name of the workload identity pool |
| <a name="output_workload_identity_provider_name"></a> [workload\_identity\_provider\_name](#output\_workload\_identity\_provider\_name) | Name of the workload identity provider |
<!-- END_TF_DOCS -->