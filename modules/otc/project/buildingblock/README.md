---
name: T Cloud Public Project
supportedPlatforms:
  - otc
description: |
  Creates a T Cloud Public (Open Telekom Cloud) project with one IAM group per meshStack role and records which federated users belong in them.
---

# T Cloud Public Project Building Block

Creates a T Cloud Public IAM project named `<region>_<project_name>` under the region's project and
one IAM group per meshStack role, each holding the T Cloud Public system roles `role_mapping` gives
it on the project.

Users are not replicated. Federated users get their groups at sign-in from the identity provider's
mapping. A provider has one mapping that every project shares, so this building block does not write
it: it records which emails belong in which of its groups as `mappings/<project>.json` in the
mapping bucket, and the [federation mapping](../../federation-mapping) building block rebuilds the
whole mapping from all of those records. A role change applies from the user's next sign-in after
that rebuild.

Without a mapping bucket (`mapping_bucket = null`) the groups are created, but nobody is mapped into
them.

## Authentication

The provider reads `OS_AUTH_URL`, `OS_DOMAIN_NAME`, `OS_ACCESS_KEY` and `OS_SECRET_KEY` from the
environment, which the meshStack integration sets from the backplane user. `tenant_name` is the
region's own project, because AK/SK authentication requires one; IAM resources go through the
provider's domain-scoped client regardless.

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
| [opentelekomcloud_identity_group_membership_v3.local](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/resources/identity_group_membership_v3) | resource |
| [opentelekomcloud_identity_group_v3.this](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/resources/identity_group_v3) | resource |
| [opentelekomcloud_identity_project_v3.this](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/resources/identity_project_v3) | resource |
| [opentelekomcloud_identity_role_assignment_v3.this](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/resources/identity_role_assignment_v3) | resource |
| [opentelekomcloud_obs_bucket_object.membership](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/resources/obs_bucket_object) | resource |
| [opentelekomcloud_identity_project_v3.region](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/data-sources/identity_project_v3) | data source |
| [opentelekomcloud_identity_role_v3.this](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/data-sources/identity_role_v3) | data source |
| [opentelekomcloud_identity_user_v3.member](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/data-sources/identity_user_v3) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_console_login_url"></a> [console\_login\_url](#input\_console\_login\_url) | Where project users sign in — the identity provider's login link when federation is set up. | `string` | `"https://console.otc.t-systems.com"` | no |
| <a name="input_mapping_bucket"></a> [mapping\_bucket](#input\_mapping\_bucket) | OBS bucket the federation mapping building block rebuilds the identity provider's mapping from. Null means no federation: members are then put into the groups as existing local IAM users instead, named like the part of their email before the `@`. | `string` | `null` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Name of the project without the region prefix. The project is created as `<region>_<project_name>`. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | T Cloud Public region the project is created in. The project name is prefixed with it, as T Cloud Public requires. | `string` | `"eu-de"` | no |
| <a name="input_role_mapping"></a> [role\_mapping](#input\_role\_mapping) | Maps each meshStack role to the T Cloud Public system roles (by role `name`, e.g. `te_admin`, `readonly`) its project group gets. Unknown meshStack roles in `users` are ignored. | `map(list(string))` | n/a | yes |
| <a name="input_users"></a> [users](#input\_users) | List of users from the authoritative system. Each user's `roles` are meshStack roles that are mapped to T Cloud Public roles via `role_mapping`. | <pre>list(object({<br/>    meshIdentifier = string<br/>    username       = string<br/>    firstName      = string<br/>    lastName       = string<br/>    email          = string<br/>    euid           = string<br/>    roles          = list(string)<br/>  }))</pre> | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_project_id"></a> [project\_id](#output\_project\_id) | ID of the created T Cloud Public project. |
| <a name="output_project_name"></a> [project\_name](#output\_project\_name) | Name of the created T Cloud Public project, including the region prefix. |
| <a name="output_project_url"></a> [project\_url](#output\_project\_url) | Where project users sign in to the T Cloud Public console. |
| <a name="output_summary"></a> [summary](#output\_summary) | Markdown summary shown in meshPanel after the run. |
<!-- END_TF_DOCS -->
