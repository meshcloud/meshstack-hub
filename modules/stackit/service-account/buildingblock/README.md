---
name: STACKIT Service Account
supportedPlatforms:
  - stackit
description: Creates a STACKIT service account inside an existing project with project roles and optional workload identity federation.
---

# STACKIT Service Account Building Block

This building block module creates a STACKIT service account inside an existing STACKIT project,
grants it the requested project roles, and optionally configures Workload Identity Federation (WIF)
providers so external workloads can assume the service account without a long-lived key.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_stackit"></a> [stackit](#requirement\_stackit) | >= 0.98.0, < 1.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [stackit_authorization_project_role_assignment.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/authorization_project_role_assignment) | resource |
| [stackit_service_account.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/service_account) | resource |
| [stackit_service_account_federated_identity_provider.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/service_account_federated_identity_provider) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_federated_identities"></a> [federated\_identities](#input\_federated\_identities) | Workload Identity Federation providers to configure on the service account, so external workloads<br/>(e.g. GitHub Actions, another cloud) can assume it without a static key. Each entry federates one<br/>external issuer/subject and pins the token audience:<br/>- `issuer`: OIDC issuer URL of the external identity provider.<br/>- `subject`: the exact `sub` claim value the external token must carry.<br/>- `audience`: the exact `aud` claim value the external token must carry. | <pre>list(object({<br/>    issuer   = string<br/>    subject  = string<br/>    audience = string<br/>  }))</pre> | `[]` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | STACKIT project ID (existing project) in which the service account will be created. | `string` | n/a | yes |
| <a name="input_roles"></a> [roles](#input\_roles) | STACKIT project roles to grant the service account within the project (e.g. "reader", "editor"). | `list(string)` | <pre>[<br/>  "reader"<br/>]</pre> | no |
| <a name="input_service_account_name"></a> [service\_account\_name](#input\_service\_account\_name) | Name of the STACKIT service account to create. Must be unique within the project. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_service_account_email"></a> [service\_account\_email](#output\_service\_account\_email) | Email of the created STACKIT service account. Use it as the principal in external federation configs and STACKIT role assignments. |
| <a name="output_service_account_url"></a> [service\_account\_url](#output\_service\_account\_url) | Deep link to the service accounts overview of the project in the STACKIT portal. |
| <a name="output_summary"></a> [summary](#output\_summary) | Summary of the created service account. |
<!-- END_TF_DOCS -->
