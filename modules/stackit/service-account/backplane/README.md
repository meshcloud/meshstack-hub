# STACKIT Service Account – Backplane

This module sets up the shared backplane configuration for the STACKIT Service Account building
block. It creates a dedicated automation service account with a Workload Identity Federation (WIF)
identity provider and the permissions required to create service accounts and assign project roles
in any project under a given organization:

- **`iam.service-account-admin`** — create and delete service accounts in projects of the
  organization. Federating them is the job of
  [`stackit/service-account-federation`](../../service-account-federation).
- **`iam.member-admin`** — assign STACKIT project roles to the created service accounts.

Both roles are granted at organization scope and cascade to every project under the organization,
because the backplane is deployed once — before the target project of any future building block
instance is known.

Authentication uses WIF (OIDC token exchange) — no long-lived service account key is created or stored.

## Governing which roles application teams can grant

`iam.member-admin` lets the automation identity assign **any** project role, including broad ones
such as `owner`. Restrict the roles application teams may pick through the building block
definition's `roles` input (see `meshstack_integration.tf`) rather than by narrowing the backplane
permissions.

## Prerequisites

- A STACKIT project where the automation service account will be created.
- A STACKIT service account with permissions to manage service accounts and organization-level role assignments.
- The STACKIT organization ID under which target projects live.
- The WIF issuer and subject meshStack resolves for the building block definition, read from `meshstack_building_block_definition.<name>.version_latest.workload_identity_federation`.

## Usage

```hcl
module "service_account_backplane" {
  source = "./backplane"

  project_id      = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  organization_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

  workload_identity_federation = {
    issuer   = meshstack_building_block_definition.this.version_latest.workload_identity_federation.issuer
    subjects = [meshstack_building_block_definition.this.version_latest.workload_identity_federation.subject]
  }
}
```

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
| [stackit_authorization_organization_role_assignment.service_account_admin](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/authorization_organization_role_assignment) | resource |
| [stackit_service_account.building_block](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/service_account) | resource |
| [stackit_service_account_federated_identity_provider.building_block](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/service_account_federated_identity_provider) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_organization_id"></a> [organization\_id](#input\_organization\_id) | STACKIT organization ID where the service account will be granted permissions to manage service accounts and role assignments. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | STACKIT project ID where the backplane service account will be created. | `string` | n/a | yes |
| <a name="input_service_account_name"></a> [service\_account\_name](#input\_service\_account\_name) | Name of the backplane service account created in the STACKIT project. Override when deploying multiple backplane instances in the same project. | `string` | `"mesh-service-account"` | no |
| <a name="input_workload_identity_federation"></a> [workload\_identity\_federation](#input\_workload\_identity\_federation) | WIF issuer URL and subject list for the meshStack building block identity provider. | <pre>object({<br/>    issuer   = string<br/>    subjects = list(string)<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_service_account_email"></a> [service\_account\_email](#output\_service\_account\_email) | Email of the STACKIT service account used by the buildingblock provider via WIF. |
<!-- END_TF_DOCS -->
