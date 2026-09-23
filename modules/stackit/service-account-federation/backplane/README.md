# STACKIT Service Account Federation – Backplane

Creates the automation service account that runs of the STACKIT Service Account Federation building
block act as. meshStack reaches it through Workload Identity Federation, so no key is created.

It holds one role, **`iam.member-admin`** at organization scope. No organization-scope role below
`organization.admin` carries `iam.service-account-federation.create`, so each run uses
`iam.member-admin` to grant itself `editor` on the one project it federates in.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_stackit"></a> [stackit](#requirement\_stackit) | >= 0.98.0, < 1.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [stackit_authorization_organization_role_assignment.member_admin](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/authorization_organization_role_assignment) | resource |
| [stackit_service_account.building_block](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/service_account) | resource |
| [stackit_service_account_federated_identity_provider.building_block](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/service_account_federated_identity_provider) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_organization_id"></a> [organization\_id](#input\_organization\_id) | STACKIT organization the backplane service account gets `iam.member-admin` in. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | STACKIT project the backplane service account is created in. | `string` | n/a | yes |
| <a name="input_service_account_name"></a> [service\_account\_name](#input\_service\_account\_name) | Name of the backplane service account. Unique within the project. | `string` | n/a | yes |
| <a name="input_workload_identity_federation"></a> [workload\_identity\_federation](#input\_workload\_identity\_federation) | WIF issuer URL and subjects of the meshStack building block runs. | <pre>object({<br/>    issuer   = string<br/>    subjects = list(string)<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_service_account_email"></a> [service\_account\_email](#output\_service\_account\_email) | Email of the service account the building block runs act as. |
<!-- END_TF_DOCS -->
