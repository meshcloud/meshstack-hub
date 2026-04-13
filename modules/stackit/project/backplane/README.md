# STACKIT Project – Backplane

This module sets up the shared backplane configuration for the STACKIT Project building block.
It creates a dedicated service account with the permissions required to create and manage
STACKIT projects under a given organization:

- **`resource-manager.admin`** — allows creating and managing projects within the organization.

> **Note:** This backplane assigns permissions at the organization scope, which is the simplest setup.
> If you use folders to organize your STACKIT projects, it is sufficient to assign the `resource-manager.admin`
> role on the folder scope instead.

## Prerequisites

- A STACKIT project where the service account will be created.
- A STACKIT service account with permissions to manage service accounts and organization-level role assignments.
- The STACKIT organization ID under which projects will be created.

## Usage

```hcl
module "project_backplane" {
  source = "./backplane"

  project_id      = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  organization_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_stackit"></a> [stackit](#requirement\_stackit) | ~> 0.89.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [stackit_authorization_organization_role_assignment.project_admin](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/authorization_organization_role_assignment) | resource |
| [stackit_service_account.building_block](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/service_account) | resource |
| [stackit_service_account_key.building_block](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/service_account_key) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_organization_id"></a> [organization\_id](#input\_organization\_id) | STACKIT organization ID where the service account will be granted permissions to create and manage projects. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | STACKIT project ID where the service account will be created. | `string` | n/a | yes |
| <a name="input_service_account_name"></a> [service\_account\_name](#input\_service\_account\_name) | Name of the service account created in the STACKIT project. Override when deploying multiple backplane instances in the same project. | `string` | `"mesh-project"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_service_account_email"></a> [service\_account\_email](#output\_service\_account\_email) | Email of the service account used by the building block to create and manage projects. |
| <a name="output_service_account_key_json"></a> [service\_account\_key\_json](#output\_service\_account\_key\_json) | Service account key JSON for authenticating the STACKIT provider in the buildingblock. |
<!-- END_TF_DOCS -->
