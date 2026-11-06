# STACKIT Service Account Federation – Backplane

Creates the automation service account that runs of the STACKIT Service Account Federation building
block act as. meshStack reaches it through Workload Identity Federation, so no key is created.

No organization-scope role below `organization.admin` carries
`iam.service-account-federation.create`. A run therefore needs `editor` on the project it federates
in, which the [STACKIT Service Account](../../service-account) building block grants this account
when it creates the service account.

## Migrating from `workload_identity_federation`

Earlier revisions took one `workload_identity_federation` object with an `issuer` and a `subjects`
list, and trusted the audience `api://AzureADTokenExchange`. Pass one entry per subject in
`workload_identity_federations`, with that issuer, the audience `api://AzureADTokenExchange` and
the subject. The identity providers keep their keys, so the plan is empty.

When a definition moves to another runner, list the old runner in `meshstack.trusted_runner_refs`.
The apply replaces the identity providers of the current runner, so building blocks on the old
runner cannot sign in until the apply is done.

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
| [stackit_service_account.building_block](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/service_account) | resource |
| [stackit_service_account_federated_identity_provider.building_block](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/service_account_federated_identity_provider) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | STACKIT project the backplane service account is created in. | `string` | n/a | yes |
| <a name="input_service_account_name"></a> [service\_account\_name](#input\_service\_account\_name) | Name of the backplane service account. Unique within the project. | `string` | n/a | yes |
| <a name="input_workload_identity_federations"></a> [workload\_identity\_federations](#input\_workload\_identity\_federations) | meshStack identities the service account trusts, one per building block runner. For more subjects of one issuer, pass one entry per subject. | <pre>list(object({<br/>    issuer   = string<br/>    audience = string<br/>    subject  = string<br/>  }))</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_service_account_email"></a> [service\_account\_email](#output\_service\_account\_email) | Email of the service account the building block runs act as. |
<!-- END_TF_DOCS -->
