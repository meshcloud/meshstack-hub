---
name: GCP Storage Bucket
supportedPlatforms:
  - gcp
description: Provides a GCP Cloud Storage bucket for object storage with access controls and lifecycle policies.
---

# GCP Storage Bucket

This Terraform module provisions a GCP Cloud Storage bucket with basic configurations.

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
| [google_storage_bucket.main](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bucket_name"></a> [bucket\_name](#input\_bucket\_name) | The name of the storage bucket | `string` | n/a | yes |
| <a name="input_labels"></a> [labels](#input\_labels) | List of labels to apply to the resource | `list(string)` | <pre>[<br>  "env:dev",<br>  "team:backend",<br>  "project:myapp"<br>]</pre> | no |
| <a name="input_location"></a> [location](#input\_location) | The GCP location/region | `string` | `"europe-west1"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The GCP project ID | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bucket_name"></a> [bucket\_name](#output\_bucket\_name) | n/a |
| <a name="output_bucket_self_link"></a> [bucket\_self\_link](#output\_bucket\_self\_link) | n/a |
| <a name="output_bucket_url"></a> [bucket\_url](#output\_bucket\_url) | n/a |
| <a name="output_summary"></a> [summary](#output\_summary) | Markdown summary output of the building block |
<!-- END_TF_DOCS -->
