---
name: T Cloud Public OBS Bucket
supportedPlatforms:
  - otc
description: |
  Creates a private, KMS-encrypted T Cloud Public OBS bucket with an access user that may use only that bucket.
requiresBackplane: true
---

# T Cloud Public OBS Bucket Building Block

Creates a private OBS bucket encrypted with its own KMS key, and an IAM user whose access key may
use only that bucket and that key. It wraps the partner module
[iits-consulting/terraform-opentelekomcloud-obs-restricted](https://github.com/iits-consulting/terraform-opentelekomcloud-obs-restricted),
pinned to a release tag.

Without a `bucket_name`, the name is derived from the project name and a random suffix, because
bucket names are unique across all of T Cloud Public.

## Project access

The IAM groups the T Cloud Public Project building block creates for the project, named
`<project>_<role>`, get access to this bucket and its key, so the project's members see it in the
console: by default admins and users read and write its objects, readers only read them
(`group_access`). OBS is a global service, so their roles on the project alone do not reach it.
Each group gets a custom role scoped to this bucket, assigned on the `MOS` project, and one for the
key on the region's project. The bucket role also lets them list every bucket name in the domain,
which the console needs before it opens one; the other buckets' content stays closed to them.

## Region project

OBS and KMS only work on a region's own project (`eu-de`, `eu-nl`), and the upstream module refuses
to run against any other. The provider therefore targets the region's project, not the application
project the building block is ordered on; that project only names the bucket. The bucket belongs to
the domain either way, while its KMS key appears under the region's project.

## Authentication

The building block holds no access key. Its runs sign in through workload identity federation:

1. meshStack mounts a token naming this definition into every run.
2. `prerun.sh` exchanges it at the identity provider in `OTC_IDENTITY_PROVIDER`, which the
   [backplane](../backplane) federates, for a federated IAM token and that for a temporary access
   key valid for one hour.
3. The provider reads the temporary key from the file the script writes. Without that file, as
   outside meshStack, it reads `OS_ACCESS_KEY` and `OS_SECRET_KEY` from the environment.

`OS_AUTH_URL` and `OS_DOMAIN_NAME` come from the environment the meshStack integration sets.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_opentelekomcloud"></a> [opentelekomcloud](#requirement\_opentelekomcloud) | >= 1.37.0, < 2.0.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.6.0, < 4.0.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_bucket"></a> [bucket](#module\_bucket) | git::https://github.com/iits-consulting/terraform-opentelekomcloud-obs-restricted.git | v7.6.2 |

## Resources

| Name | Type |
|------|------|
| [opentelekomcloud_identity_role_assignment_v3.bucket](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/resources/identity_role_assignment_v3) | resource |
| [opentelekomcloud_identity_role_assignment_v3.key](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/resources/identity_role_assignment_v3) | resource |
| [opentelekomcloud_identity_role_v3.bucket](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/resources/identity_role_v3) | resource |
| [opentelekomcloud_identity_role_v3.key](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/resources/identity_role_v3) | resource |
| [random_string.bucket_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [opentelekomcloud_identity_group_v3.project](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/data-sources/identity_group_v3) | data source |
| [opentelekomcloud_identity_project_v3.obs](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/data-sources/identity_project_v3) | data source |
| [opentelekomcloud_identity_project_v3.region](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/data-sources/identity_project_v3) | data source |
| [opentelekomcloud_identity_project_v3.tenant](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/data-sources/identity_project_v3) | data source |
| [opentelekomcloud_kms_key_v1.bucket](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/data-sources/kms_key_v1) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bucket_name"></a> [bucket\_name](#input\_bucket\_name) | Bucket name, unique across all of T Cloud Public. Null derives one from the project name and a random suffix. | `string` | `null` | no |
| <a name="input_enable_versioning"></a> [enable\_versioning](#input\_enable\_versioning) | Keep previous versions of overwritten and deleted objects. | `bool` | `true` | no |
| <a name="input_force_destroy"></a> [force\_destroy](#input\_force\_destroy) | Delete all objects with the bucket when the building block is deleted. Without it, deleting a non-empty bucket fails. | `bool` | `false` | no |
| <a name="input_group_access"></a> [group\_access](#input\_group\_access) | Access to the bucket each meshStack project role's IAM group gets, `read` or `write`. The project building block names the groups `<project>_<role>`. | `map(string)` | <pre>{<br/>  "admin": "write",<br/>  "reader": "read",<br/>  "user": "write"<br/>}</pre> | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | ID of the application project this building block is ordered on. Its name seeds the default bucket name. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | T Cloud Public region the bucket and its KMS key are created in. | `string` | `"eu-de"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_access_key"></a> [access\_key](#output\_access\_key) | Access key of the user that may only use this bucket and its KMS key. |
| <a name="output_bucket_name"></a> [bucket\_name](#output\_bucket\_name) | Name of the bucket. |
| <a name="output_obs_endpoint"></a> [obs\_endpoint](#output\_obs\_endpoint) | S3-compatible endpoint to reach the bucket at. |
| <a name="output_secret_key"></a> [secret\_key](#output\_secret\_key) | Secret key belonging to `access_key`. |
| <a name="output_summary"></a> [summary](#output\_summary) | Markdown summary shown in meshPanel after the run. |
<!-- END_TF_DOCS -->
