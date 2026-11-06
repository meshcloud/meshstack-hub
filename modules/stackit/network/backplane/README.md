# STACKIT Network – Backplane

This module sets up the shared backplane configuration for the STACKIT Network building block.
It creates a dedicated service account with a Workload Identity Federation (WIF) identity
provider and the permissions required to create STACKIT networks in any project under a given
organization:

- **`iaas.network.admin`** — allows creating networks within projects of the organization.

Authentication uses WIF (OIDC token exchange) — no long-lived service account key is created or stored.

## Prerequisites

- A STACKIT project where the service account will be created.
- A STACKIT service account with permissions to manage service accounts and organization-level role assignments.
- The STACKIT organization ID under which target projects live.
- One identity per building block runner, read from [`modules/meshstack/runner-identity`](../../../meshstack/runner-identity) with `cloud = "azure"`.

## Usage

```hcl
module "network_backplane" {
  source = "./backplane"

  project_id      = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  organization_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

  workload_identity_federations = module.runner_identity.identities
}
```

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
| [stackit_authorization_organization_role_assignment.network_admin](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/authorization_organization_role_assignment) | resource |
| [stackit_service_account.building_block](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/service_account) | resource |
| [stackit_service_account_federated_identity_provider.building_block](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/service_account_federated_identity_provider) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_organization_id"></a> [organization\_id](#input\_organization\_id) | STACKIT organization ID where the service account will be granted permissions to manage networks. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | STACKIT project ID where the service account will be created. | `string` | n/a | yes |
| <a name="input_service_account_name"></a> [service\_account\_name](#input\_service\_account\_name) | Name of the service account created in the STACKIT project. Override when deploying multiple backplane instances in the same project. | `string` | `"mesh-network"` | no |
| <a name="input_workload_identity_federations"></a> [workload\_identity\_federations](#input\_workload\_identity\_federations) | meshStack identities the service account trusts, one per building block runner. For more subjects of one issuer, pass one entry per subject. | <pre>list(object({<br/>    issuer   = string<br/>    audience = string<br/>    subject  = string<br/>  }))</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_service_account_email"></a> [service\_account\_email](#output\_service\_account\_email) | Email of the STACKIT service account used by the buildingblock provider via WIF. |
<!-- END_TF_DOCS -->