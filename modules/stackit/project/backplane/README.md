# STACKIT Project – Backplane

This module sets up the shared backplane configuration for the STACKIT Project building block.
It creates a dedicated service account with a Workload Identity Federation (WIF) identity provider
and the permissions required to create and manage STACKIT projects under a given organization:

- **`resource-manager.admin`** — allows creating and managing projects within the organization.

Authentication uses WIF (OIDC token exchange) — no long-lived service account key is created or stored.

> **Note:** This backplane assigns permissions at the organization scope, which is the simplest setup.
> If you use folders to organize your STACKIT projects, it is sufficient to assign the `resource-manager.admin`
> role on the folder scope instead.

## Prerequisites

- A STACKIT project where the service account will be created.
- A STACKIT service account with permissions to manage service accounts and organization-level role assignments.
- The STACKIT organization ID under which projects will be created.
- meshStack WIF issuer and subject from `data.meshstack_integrations.integrations`.

## Usage

```hcl
module "project_backplane" {
  source = "./backplane"

  project_id      = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  organization_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

  workload_identity_federation = {
    issuer   = data.meshstack_integrations.integrations.workload_identity_federation.replicator.issuer
    subjects = ["<meshstack-wif-subject>"]
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_stackit"></a> [stackit](#requirement\_stackit) | >= 0.98.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [stackit_authorization_organization_role_assignment.project_admin](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/authorization_organization_role_assignment) | resource |
| [stackit_service_account.building_block](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/service_account) | resource |
| [stackit_service_account_federated_identity_provider.building_block](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/service_account_federated_identity_provider) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_organization_id"></a> [organization\_id](#input\_organization\_id) | STACKIT organization ID where the service account will be granted permissions to create and manage projects. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | STACKIT project ID where the service account will be created. | `string` | n/a | yes |
| <a name="input_service_account_name"></a> [service\_account\_name](#input\_service\_account\_name) | Name of the service account created in the STACKIT project. Override when deploying multiple backplane instances in the same project. | `string` | `"mesh-project"` | no |
| <a name="input_workload_identity_federation"></a> [workload\_identity\_federation](#input\_workload\_identity\_federation) | WIF issuer URL and subject list for the meshStack building block identity provider. | <pre>object({<br/>    issuer   = string<br/>    subjects = list(string)<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_service_account_email"></a> [service\_account\_email](#output\_service\_account\_email) | Email of the STACKIT service account used by the buildingblock provider via WIF. |
<!-- END_TF_DOCS -->
