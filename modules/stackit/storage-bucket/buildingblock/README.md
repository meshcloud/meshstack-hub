---
name: STACKIT Storage Bucket
supportedPlatforms:
  - stackit
description: Provisions an S3-compatible Object Storage bucket on STACKIT with access credentials.
---

# STACKIT Storage Bucket Building Block

This building block module provisions a STACKIT Object Storage bucket with S3-compatible access credentials.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |
| <a name="requirement_stackit"></a> [stackit](#requirement\_stackit) | ~> 0.82.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_s3_bucket.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [stackit_objectstorage_credential.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/objectstorage_credential) | resource |
| [stackit_objectstorage_credentials_group.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/objectstorage_credentials_group) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_admin_credentials_group_urn"></a> [admin\_credentials\_group\_urn](#input\_admin\_credentials\_group\_urn) | URN of the admin credentials group used to apply bucket policies (e.g. urn:sgws:identity::<account\_id>:group/<group\_id>). | `string` | n/a | yes |
| <a name="input_admin_s3_access_key"></a> [admin\_s3\_access\_key](#input\_admin\_s3\_access\_key) | S3 access key for the admin credentials group used to apply bucket policies. | `string` | n/a | yes |
| <a name="input_admin_s3_secret_access_key"></a> [admin\_s3\_secret\_access\_key](#input\_admin\_s3\_secret\_access\_key) | S3 secret access key for the admin credentials group used to apply bucket policies. | `string` | n/a | yes |
| <a name="input_bucket_name"></a> [bucket\_name](#input\_bucket\_name) | Name of the Object Storage bucket. Must be DNS-conformant. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | STACKIT project ID where the bucket will be created. | `string` | n/a | yes |
| <a name="input_service_account_key_json"></a> [service\_account\_key\_json](#input\_service\_account\_key\_json) | Service account key JSON for authenticating the STACKIT provider. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bucket_name"></a> [bucket\_name](#output\_bucket\_name) | Name of the created Object Storage bucket. |
| <a name="output_bucket_url_path_style"></a> [bucket\_url\_path\_style](#output\_bucket\_url\_path\_style) | Path-style URL of the bucket. |
| <a name="output_bucket_url_virtual_hosted_style"></a> [bucket\_url\_virtual\_hosted\_style](#output\_bucket\_url\_virtual\_hosted\_style) | Virtual-hosted-style URL of the bucket. |
| <a name="output_s3_access_key"></a> [s3\_access\_key](#output\_s3\_access\_key) | S3-compatible access key for the bucket. |
| <a name="output_s3_secret_access_key"></a> [s3\_secret\_access\_key](#output\_s3\_secret\_access\_key) | S3-compatible secret access key for the bucket. |
| <a name="output_summary"></a> [summary](#output\_summary) | Summary with bucket details and access credentials. |
<!-- END_TF_DOCS -->
