---
name: T Cloud Public Project
supportedPlatforms:
  - otc
description: |
  Creates a T Cloud Public (Open Telekom Cloud) project with one IAM group per meshStack role and maps federated project users into those groups.
---

# T Cloud Public Project Building Block

Creates a T Cloud Public IAM project named `<region>_<project_name>` under the region's project and
one IAM group per meshStack role, each holding the T Cloud Public system roles `role_mapping` gives
it on the project.

Users are not replicated. When an identity provider is federated (see the backplane), the building
block writes one mapping rule per role into the identity provider's mapping, matching the role's
users by email. Federated users sign in as virtual users and receive the groups at sign-in, so a
role change applies from the user's next sign-in.

The identity provider has a single mapping that every project shares. `federation_mapping.py` merges
this project's rules in and out of it, owns exactly the rules that name one of this project's
groups, and re-reads the mapping after writing to retry if a concurrent run overwrote it.

## Authentication

The provider and the script read `OS_AUTH_URL`, `OS_DOMAIN_NAME`, `OS_USERNAME` and `OS_PASSWORD`
from the environment, which the meshStack integration sets from the backplane user. The token is
domain-scoped, because the backplane grants its roles on the domain.

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
| [opentelekomcloud_identity_group_v3.this](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/resources/identity_group_v3) | resource |
| [opentelekomcloud_identity_project_v3.this](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/resources/identity_project_v3) | resource |
| [opentelekomcloud_identity_role_assignment_v3.this](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/resources/identity_role_assignment_v3) | resource |
| [terraform_data.federation_mapping](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [opentelekomcloud_identity_project_v3.region](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/data-sources/identity_project_v3) | data source |
| [opentelekomcloud_identity_role_v3.this](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/data-sources/identity_role_v3) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_console_login_url"></a> [console\_login\_url](#input\_console\_login\_url) | Where project users sign in — the identity provider's login link when federation is set up. | `string` | `"https://console.otc.t-systems.com"` | no |
| <a name="input_identity_provider_email_attribute"></a> [identity\_provider\_email\_attribute](#input\_identity\_provider\_email\_attribute) | SAML attribute or OIDC claim that carries the user's email address, matched against meshStack users' `email`. | `string` | `"email"` | no |
| <a name="input_identity_provider_name"></a> [identity\_provider\_name](#input\_identity\_provider\_name) | Federated identity provider whose mapping puts project users into the project groups. Null creates the groups without mapping anyone into them. | `string` | `null` | no |
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
