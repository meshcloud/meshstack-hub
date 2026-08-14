---
name: STACKIT Storage Bucket
supportedPlatforms:
  - stackit
description: Provisions an S3-compatible Object Storage bucket on STACKIT with access credentials.
---

# STACKIT Storage Bucket Building Block

This building block module provisions a STACKIT Object Storage bucket with S3-compatible access
credentials. Each bucket gets its own credentials group, and the bucket policy denies every
principal outside that group and the admin group the backplane owns. The bucket is therefore the
isolation boundary: a credential reaches exactly one bucket.

## Two ways to use the module

The module has two entry points, and they differ only in who configures the providers.

`buildingblock/` is the root meshStack runs when an application team orders the building block. It
configures the `stackit` provider and the `aws` provider, the latter pointed at STACKIT Object
Storage, and calls `buildingblock/bucket` once.

`buildingblock/bucket` holds the bucket, the credentials group, the credential and the bucket
policy, and declares no provider configuration. A composition that creates one bucket per tenant
sources this module. It cannot source `buildingblock/`, because a module that carries its own
provider configuration is a legacy module and OpenTofu rejects `count`, `for_each` and `depends_on`
on every call to it.

```hcl
provider "aws" {
  access_key = var.admin_s3_access_key
  secret_key = var.admin_s3_secret_access_key
  region     = "eu01"

  endpoints {
    s3 = "https://object.storage.eu01.onstackit.cloud"
  }

  skip_credentials_validation = true
  skip_region_validation      = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  s3_use_path_style           = true
}

module "tenant_bucket" {
  for_each = var.tenants
  source   = "github.com/meshcloud/meshstack-hub//modules/stackit/storage-bucket/buildingblock/bucket?ref=main"

  project_id                  = var.stackit_project_id
  bucket_name                 = "langfuse-${each.key}"
  admin_credentials_group_urn = var.admin_credentials_group_urn
}
```

The S3 credentials the `aws` provider uses must belong to the credentials group named by
`admin_credentials_group_urn`. The bucket policy keeps access for that group, so a mismatch locks
the caller out of the bucket it just created. The backplane emits both values.

## Region

The module serves one region, `eu01`, and hardcodes its endpoint
`https://object.storage.eu01.onstackit.cloud`. The `region` output reports the value, so a caller
that has to configure an S3 client does not hardcode it a second time.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.0, < 5.0 |
| <a name="requirement_stackit"></a> [stackit](#requirement\_stackit) | >= 0.82.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_bucket"></a> [bucket](#module\_bucket) | ./bucket | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_admin_credentials_group_urn"></a> [admin\_credentials\_group\_urn](#input\_admin\_credentials\_group\_urn) | URN of the admin credentials group used to apply bucket policies (e.g. urn:sgws:identity::<account\_id>:group/<group\_id>). | `string` | n/a | yes |
| <a name="input_admin_s3_access_key"></a> [admin\_s3\_access\_key](#input\_admin\_s3\_access\_key) | S3 access key for the admin credentials group used to apply bucket policies. | `string` | n/a | yes |
| <a name="input_admin_s3_secret_access_key"></a> [admin\_s3\_secret\_access\_key](#input\_admin\_s3\_secret\_access\_key) | S3 secret access key for the admin credentials group used to apply bucket policies. | `string` | n/a | yes |
| <a name="input_bucket_name"></a> [bucket\_name](#input\_bucket\_name) | Name of the Object Storage bucket. Must be DNS-conformant: 3 to 63 characters, lowercase letters, digits, hyphens and dots, starting and ending with a letter or a digit. The credentials group created for the bucket carries the same name, so the name must be unique within the project. `./bucket` validates the value. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | STACKIT project ID where the bucket will be created. | `string` | n/a | yes |
| <a name="input_service_account_email"></a> [service\_account\_email](#input\_service\_account\_email) | Email of the STACKIT service account for WIF-based authentication. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bucket_name"></a> [bucket\_name](#output\_bucket\_name) | Name of the created Object Storage bucket. |
| <a name="output_bucket_url_path_style"></a> [bucket\_url\_path\_style](#output\_bucket\_url\_path\_style) | Path-style URL of the bucket. |
| <a name="output_bucket_url_virtual_hosted_style"></a> [bucket\_url\_virtual\_hosted\_style](#output\_bucket\_url\_virtual\_hosted\_style) | Virtual-hosted-style URL of the bucket. |
| <a name="output_credentials_group_urn"></a> [credentials\_group\_urn](#output\_credentials\_group\_urn) | URN of the credentials group the bucket policy grants read and write access to. The access key belongs to this group. |
| <a name="output_endpoint"></a> [endpoint](#output\_endpoint) | Base URL of the STACKIT Object Storage S3 endpoint, without the bucket name. Use this for S3 clients that take an endpoint and a bucket separately. |
| <a name="output_region"></a> [region](#output\_region) | STACKIT region the bucket lives in. S3 clients that require a region, among them the AWS SDK and the Langfuse S3 configuration, take this value. |
| <a name="output_s3_access_key"></a> [s3\_access\_key](#output\_s3\_access\_key) | S3-compatible access key for the bucket. |
| <a name="output_s3_secret_access_key"></a> [s3\_secret\_access\_key](#output\_s3\_secret\_access\_key) | S3-compatible secret access key for the bucket. |
| <a name="output_summary"></a> [summary](#output\_summary) | Summary with bucket details and access credentials. |
<!-- END_TF_DOCS -->
