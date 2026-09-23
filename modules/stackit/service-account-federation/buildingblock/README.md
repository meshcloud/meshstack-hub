---
name: STACKIT Service Account Federation
supportedPlatforms:
  - stackit
description: Lets runs of the listed building block definitions act as an existing STACKIT service account through workload identity federation.
---

# STACKIT Service Account Federation Building Block

Creates one workload identity federation provider on an existing STACKIT service account for each
listed building block definition of the ordering workspace. Runs of those definitions can then act
as the service account without a long-lived key.

## Why this is not part of the service account block

A composing architecture creates the service account first. Then it registers the definitions that
act as that account, and only then does it know their uuids. If one block both created the account
and federated the uuids, the account would depend on the definitions, and no definition could read
the account's email. It could also not be the parent of the blocks that act as it.

So the two are split:

- The [STACKIT Service Account](../../service-account) block creates the account and grants its roles.
- This block federates the definitions. It is ordered as a child of the service account block, and
  the blocks that act as the account are ordered as its children.

## How the run gets its permission

Its backplane holds `iam.member-admin` at organization scope. No organization-scope role below
`organization.admin` carries `iam.service-account-federation.create`. So the run grants itself
`editor` on the service account's project, and `wait-for-federation-access.sh` polls until that
assignment is in effect.

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
| [stackit_service_account_federated_identity_provider.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/service_account_federated_identity_provider) | resource |
| [terraform_data.federation_access](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [meshstack_integrations.this](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/data-sources/integrations) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_automation_service_account_email"></a> [automation\_service\_account\_email](#input\_automation\_service\_account\_email) | Email of the service account this run acts as. It grants itself `editor` on the project to create federations. | `string` | n/a | yes |
| <a name="input_federated_building_block_definitions"></a> [federated\_building\_block\_definitions](#input\_federated\_building\_block\_definitions) | UUIDs of building block definitions whose runs may act as the service account. | `list(string)` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | STACKIT project the service account lives in. | `string` | n/a | yes |
| <a name="input_service_account_email"></a> [service\_account\_email](#input\_service\_account\_email) | Email of the STACKIT service account to federate. | `string` | n/a | yes |
| <a name="input_workspace_identifier"></a> [workspace\_identifier](#input\_workspace\_identifier) | Workspace that owns the federated building block definitions. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_service_account_email"></a> [service\_account\_email](#output\_service\_account\_email) | Email of the federated service account. Children of this block authenticate as it. |
| <a name="output_summary"></a> [summary](#output\_summary) | Summary of the federation. |
<!-- END_TF_DOCS -->
