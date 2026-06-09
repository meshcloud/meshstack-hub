# STACKIT Storage Bucket – Backplane

This module sets up the shared backplane configuration for the STACKIT Storage Bucket building block.
It creates a dedicated service account with least-privilege permissions in the target STACKIT project
and registers a Workload Identity Federation (WIF) provider so meshStack can authenticate without
long-lived keys:

- **`object-storage.admin`** — allows managing Object Storage buckets, credentials groups, and credentials.
- **`object-storage.service-account-admin`** — allows creating per-bucket credentials groups and credentials from the building block.

Additionally, an admin S3 credentials group is created whose credentials are used by the building block
to apply bucket policies via the S3 API.

## Prerequisites

- A STACKIT service account with permissions to manage service accounts, IAM, and Object Storage in the target project.
- The STACKIT project must already exist.
- A meshStack installation with Workload Identity Federation enabled (provides `issuer` and `subject`).

## Usage

```hcl
module "storage_bucket_backplane" {
  source = "./backplane"

  project_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

  workload_identity_federation = {
    issuer   = data.meshstack_integrations.integrations.workload_identity_federation.replicator.issuer
    subjects = ["<meshstack-building-block-subject>"]
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_stackit"></a> [stackit](#requirement\_stackit) | ~> 0.98.0 |

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
| [stackit_service_account_federated_identity_provider.building_block](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/service_account_federated_identity_provider) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | STACKIT project ID where Object Storage buckets will be created. | `string` | n/a | yes |
| <a name="input_service_account_name"></a> [service\_account\_name](#input\_service\_account\_name) | Name of the service account created in the STACKIT project. Override when deploying multiple backplane instances in the same project. | `string` | `"mesh-storage-bucket"` | no |
| <a name="input_workload_identity_federation"></a> [workload\_identity\_federation](#input\_workload\_identity\_federation) | WIF issuer URL and subject list for the meshStack building block identity provider. | <pre>object({<br/>    issuer   = string<br/>    subjects = list(string)<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_admin_credentials_group_urn"></a> [admin\_credentials\_group\_urn](#output\_admin\_credentials\_group\_urn) | URN of the admin credentials group used to manage bucket policies. |
| <a name="output_admin_s3_access_key"></a> [admin\_s3\_access\_key](#output\_admin\_s3\_access\_key) | S3 access key for the admin credentials group used to manage bucket policies. |
| <a name="output_admin_s3_secret_access_key"></a> [admin\_s3\_secret\_access\_key](#output\_admin\_s3\_secret\_access\_key) | S3 secret access key for the admin credentials group used to manage bucket policies. |
| <a name="output_project_id"></a> [project\_id](#output\_project\_id) | STACKIT project ID for Object Storage bucket creation. |
| <a name="output_service_account_email"></a> [service\_account\_email](#output\_service\_account\_email) | Email of the STACKIT service account used by the buildingblock provider via WIF. |
<!-- END_TF_DOCS -->
