# STACKIT Storage Bucket – Backplane

This module sets up the shared backplane configuration for the STACKIT Storage Bucket building block.
It creates a dedicated service account with least-privilege permissions in the target STACKIT project:

- **`object-storage.admin`** — allows managing Object Storage buckets, credentials groups, and credentials.
- **`object-storage.service-account-admin`** — allows creating per-bucket credentials groups and credentials from the building block.

Additionally, an admin S3 credentials group is created whose credentials are used by the building block
to apply bucket policies via the S3 API.

## Prerequisites

- A STACKIT service account with permissions to manage service accounts and Object Storage in the target project.
- The STACKIT project must already exist.

## Usage

```hcl
module "storage_bucket_backplane" {
  source = "./backplane"

  project_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_stackit"></a> [stackit](#requirement\_stackit) | ~> 0.88.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [stackit_authorization_project_role_assignment.object_storage](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/authorization_project_role_assignment) | resource |
| [stackit_authorization_project_role_assignment.service_account](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/authorization_project_role_assignment) | resource |
| [stackit_objectstorage_credential.admin](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/objectstorage_credential) | resource |
| [stackit_objectstorage_credentials_group.admin](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/objectstorage_credentials_group) | resource |
| [stackit_service_account.building_block](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/service_account) | resource |
| [stackit_service_account_key.building_block](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/service_account_key) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | STACKIT project ID where Object Storage buckets will be created. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_admin_credentials_group_urn"></a> [admin\_credentials\_group\_urn](#output\_admin\_credentials\_group\_urn) | URN of the admin credentials group used to manage bucket policies. |
| <a name="output_admin_s3_access_key"></a> [admin\_s3\_access\_key](#output\_admin\_s3\_access\_key) | S3 access key for the admin credentials group used to manage bucket policies. |
| <a name="output_admin_s3_secret_access_key"></a> [admin\_s3\_secret\_access\_key](#output\_admin\_s3\_secret\_access\_key) | S3 secret access key for the admin credentials group used to manage bucket policies. |
| <a name="output_project_id"></a> [project\_id](#output\_project\_id) | STACKIT project ID for Object Storage bucket creation. |
| <a name="output_service_account_key_json"></a> [service\_account\_key\_json](#output\_service\_account\_key\_json) | Service account key JSON for authenticating the STACKIT provider in the buildingblock. |
<!-- END_TF_DOCS -->
