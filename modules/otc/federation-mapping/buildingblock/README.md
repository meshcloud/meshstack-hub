---
name: T Cloud Public Federation Mapping
supportedPlatforms:
  - otc
description: |
  Runs the function that rebuilds the federated identity provider's mapping from the group membership every T Cloud Public project building block records.
# The building block authenticates with the project building block's backplane user, which the
# composing reference architecture passes in; it provisions no cloud-side identity of its own.
requiresBackplane: false
---

# T Cloud Public Federation Mapping Building Block

T Cloud Public gives a federated user their IAM groups at sign-in, from the identity provider's
mapping. A provider has exactly one mapping, but every project contributes rules to it. So no
project writes the mapping: each records its membership as `mappings/<project>.json` in a bucket,
and this building block runs a FunctionGraph function that rebuilds the whole mapping from all of
them.

The function runs in the management project, the tenant this building block is ordered on:

- **OBS trigger** on `mappings/*.json`: a project created, changed or deleted rebuilds the mapping.
- **Timer trigger** (`resync_schedule`, default hourly): rebuilds it regardless, which repairs a
  dropped event.
- **One instance at a time** (`max_instance_num = 1`): two rebuilds never interleave.

The function acts as an agency delegated to FunctionGraph, holding Security Administrator for the
mapping and OBS ReadOnlyAccess for the bucket. It uses only the Python standard library.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_opentelekomcloud"></a> [opentelekomcloud](#requirement\_opentelekomcloud) | >= 1.37.0, < 2.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [opentelekomcloud_fgs_function_v2.this](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/resources/fgs_function_v2) | resource |
| [opentelekomcloud_fgs_trigger_v2.bucket](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/resources/fgs_trigger_v2) | resource |
| [opentelekomcloud_fgs_trigger_v2.resync](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/resources/fgs_trigger_v2) | resource |
| [opentelekomcloud_identity_agency_v3.function](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/resources/identity_agency_v3) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_email_attribute"></a> [email\_attribute](#input\_email\_attribute) | SAML attribute or OIDC claim that carries the user's email address, matched against the recorded emails. | `string` | `"email"` | no |
| <a name="input_identity_provider_name"></a> [identity\_provider\_name](#input\_identity\_provider\_name) | Federated identity provider whose mapping the function rebuilds. | `string` | n/a | yes |
| <a name="input_mapping_bucket"></a> [mapping\_bucket](#input\_mapping\_bucket) | OBS bucket project building blocks record their group membership in, as `mappings/<project>.json`. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the function and its agency. Agency names are unique across the domain. | `string` | `"meshstack-idp-mapping"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | ID of the management project the function runs in. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | T Cloud Public region of the management project and the mapping bucket. | `string` | `"eu-de"` | no |
| <a name="input_resync_schedule"></a> [resync\_schedule](#input\_resync\_schedule) | How often the function rebuilds the mapping regardless of bucket events, as a FunctionGraph cron schedule. | `string` | `"@every 1h"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_function_urn"></a> [function\_urn](#output\_function\_urn) | URN of the function that rebuilds the mapping. |
| <a name="output_summary"></a> [summary](#output\_summary) | Markdown summary shown in meshPanel after the run. |
<!-- END_TF_DOCS -->
