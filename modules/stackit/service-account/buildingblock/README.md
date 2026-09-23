---
name: STACKIT Service Account
supportedPlatforms:
  - stackit
description: Creates a STACKIT service account inside an existing project with project roles and optional workload identity federation.
---

# STACKIT Service Account Building Block

This building block module creates a STACKIT service account inside an existing STACKIT project,
grants it the requested project roles, and optionally configures Workload Identity Federation (WIF)
providers so runs of the listed building block definitions of the ordering workspace can act as the
service account without a long-lived key.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_meshstack"></a> [meshstack](#requirement\_meshstack) | >= 0.24.0, < 1.0.0 |
| <a name="requirement_stackit"></a> [stackit](#requirement\_stackit) | >= 0.98.0, < 1.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [stackit_authorization_project_role_assignment.federation_admin](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/authorization_project_role_assignment) | resource |
| [stackit_authorization_project_role_assignment.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/authorization_project_role_assignment) | resource |
| [stackit_service_account.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/service_account) | resource |
| [stackit_service_account_federated_identity_provider.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/service_account_federated_identity_provider) | resource |
| [terraform_data.federation_access](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [meshstack_integrations.this](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/data-sources/integrations) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_automation_service_account_email"></a> [automation\_service\_account\_email](#input\_automation\_service\_account\_email) | Email of the service account this run acts as. It grants itself `editor` on the project to create federations. | `string` | n/a | yes |
| <a name="input_federated_building_block_definitions"></a> [federated\_building\_block\_definitions](#input\_federated\_building\_block\_definitions) | UUIDs of building block definitions whose runs may act as this service account via WIF. | `list(string)` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | STACKIT project ID (existing project) in which the service account will be created. | `string` | n/a | yes |
| <a name="input_roles"></a> [roles](#input\_roles) | STACKIT project roles to grant the service account within the project (e.g. "reader", "editor"). | `list(string)` | n/a | yes |
| <a name="input_service_account_name"></a> [service\_account\_name](#input\_service\_account\_name) | Name of the STACKIT service account to create. Must be unique within the project. | `string` | n/a | yes |
| <a name="input_workspace_identifier"></a> [workspace\_identifier](#input\_workspace\_identifier) | Workspace that owns the federated building block definitions. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_service_account_email"></a> [service\_account\_email](#output\_service\_account\_email) | Email of the created STACKIT service account. Use it as the principal in external federation configs and STACKIT role assignments. |
| <a name="output_service_account_id"></a> [service\_account\_id](#output\_service\_account\_id) | Id of the created STACKIT service account. Forms asking for a service account often want this next to the email, e.g. linking a Harbor robot. |
| <a name="output_service_account_url"></a> [service\_account\_url](#output\_service\_account\_url) | Deep link to the service accounts overview of the project in the STACKIT portal. |
| <a name="output_summary"></a> [summary](#output\_summary) | Summary of the created service account. |
<!-- END_TF_DOCS -->
