---
name: OVHcloud Project
supportedPlatforms:
  - ovh
# The credential is a classic OVHcloud API credential created by hand: OVHcloud service accounts
# cannot order products, and Terraform cannot create consumer keys, so a backplane has nothing to set up.
requiresBackplane: false
description: |
  Orders an OVHcloud Public Cloud project and grants meshStack project members access to it through OVHcloud IAM policies.
---

# OVHcloud Project Building Block

Orders an OVHcloud Public Cloud project described as `<workspace_identifier>-<project_identifier>`
and creates one IAM policy per meshStack role, allowing the role's members the actions
`role_mapping` gives it on the project.

Users are not created. A member's OVHcloud identity is the existing local user in the `DEFAULT`
group named like the part of their email before the `@`. Members without one get no access, and
the summary lists them.

## Authentication

The provider reads `OVH_APPLICATION_KEY`, `OVH_APPLICATION_SECRET` and `OVH_CONSUMER_KEY` from the
environment, which the meshStack integration sets. The API endpoint is the `endpoint` input.

An OVHcloud service account cannot do this: the order API refuses to assign a cart to it, so it
cannot order a project. Create the credential at [createToken](https://eu.api.ovh.com/createToken/)
(or the matching page of your endpoint) as an account administrator, and restrict the consumer key
to the paths the building block calls, with `GET`, `POST`, `PUT` and `DELETE` on each:

- `/me/*`
- `/order/*`
- `/cloud/project/*`
- `/iam/*`
- `/services/*`

These rules are not verified as the narrowest set yet.

## Costs

Ordering a project bills the OVHcloud account's default payment method. A project itself is free;
the resources created in it are billed pay-as-you-go.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_ovh"></a> [ovh](#requirement\_ovh) | >= 2.0.0, < 3.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [ovh_cloud_project.this](https://registry.terraform.io/providers/ovh/ovh/latest/docs/resources/cloud_project) | resource |
| [ovh_iam_policy.role](https://registry.terraform.io/providers/ovh/ovh/latest/docs/resources/iam_policy) | resource |
| [ovh_me.this](https://registry.terraform.io/providers/ovh/ovh/latest/docs/data-sources/me) | data source |
| [ovh_me_identity_user.all](https://registry.terraform.io/providers/ovh/ovh/latest/docs/data-sources/me_identity_user) | data source |
| [ovh_me_identity_users.all](https://registry.terraform.io/providers/ovh/ovh/latest/docs/data-sources/me_identity_users) | data source |
| [ovh_order_cart.this](https://registry.terraform.io/providers/ovh/ovh/latest/docs/data-sources/order_cart) | data source |
| [ovh_order_cart_product_plan.project](https://registry.terraform.io/providers/ovh/ovh/latest/docs/data-sources/order_cart_product_plan) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_endpoint"></a> [endpoint](#input\_endpoint) | OVHcloud API endpoint, e.g. `ovh-eu`, `ovh-ca` or `ovh-us`. | `string` | n/a | yes |
| <a name="input_project_identifier"></a> [project\_identifier](#input\_project\_identifier) | meshStack project identifier. The project is described as `<workspace_identifier>-<project_identifier>`. | `string` | n/a | yes |
| <a name="input_role_mapping"></a> [role\_mapping](#input\_role\_mapping) | Maps each meshStack role to the OVHcloud IAM actions its members get on the project, e.g. `publicCloudProject:apiovh:*`. Unknown meshStack roles in `users` are ignored. | `map(list(string))` | n/a | yes |
| <a name="input_users"></a> [users](#input\_users) | List of users from the authoritative system. Each user's `roles` are meshStack roles that are mapped to OVHcloud IAM actions via `role_mapping`. | <pre>list(object({<br/>    meshIdentifier = string<br/>    username       = string<br/>    firstName      = string<br/>    lastName       = string<br/>    email          = string<br/>    euid           = string<br/>    roles          = list(string)<br/>  }))</pre> | n/a | yes |
| <a name="input_workspace_identifier"></a> [workspace\_identifier](#input\_workspace\_identifier) | meshStack workspace identifier. The project is described as `<workspace_identifier>-<project_identifier>`. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_project_id"></a> [project\_id](#output\_project\_id) | ID of the created Public Cloud project. |
| <a name="output_project_url"></a> [project\_url](#output\_project\_url) | Link to the project in the OVHcloud Control Panel. |
| <a name="output_project_urn"></a> [project\_urn](#output\_project\_urn) | IAM resource URN of the created Public Cloud project. |
| <a name="output_summary"></a> [summary](#output\_summary) | Markdown summary shown in meshPanel after the run. |
<!-- END_TF_DOCS -->
