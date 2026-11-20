# STACKIT PostgreSQL – Backplane

Optional. By default the definition runs as a service account the platform provides, see
[Identity](../buildingblock/README.md#identity). `create_backplane = true` creates this backplane for
a meshStack without the `stackit/service-account` building blocks.

It creates a dedicated service account in the project of the instances and registers a Workload
Identity Federation (WIF) provider, so meshStack can authenticate without long-lived keys:

- **`postgres-flex.admin`** on the project — allows creating and deleting PostgreSQL Flex instances,
  databases and users. `postgres-flex.editor` has no delete permission, and the building block
  definition deletes what it created.

## Prerequisites

- A STACKIT service account with permissions to manage service accounts and role assignments in
  the project.
- The caller's STACKIT provider sets `experiments = ["iam"]`.
- A meshStack installation with Workload Identity Federation enabled (provides `issuer` and `subject`).

## Usage

```hcl
module "postgres_backplane" {
  source = "./backplane"

  project_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

  workload_identity_federation = {
    issuer   = module.runner.issuer
    audience = module.runner.audience
    subjects = [meshstack_building_block_definition.this.version_latest.workload_identity_federation.subject]
  }
}
```

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
| [stackit_authorization_project_role_assignment.postgres_flex_admin](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/authorization_project_role_assignment) | resource |
| [stackit_service_account.building_block](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/service_account) | resource |
| [stackit_service_account_federated_identity_provider.building_block](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/service_account_federated_identity_provider) | resource |
| [stackit_service_account_federated_identity_provider.trusted_runner](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/service_account_federated_identity_provider) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | STACKIT project ID where the backplane service account is created and the building block creates its instances. | `string` | n/a | yes |
| <a name="input_service_account_name"></a> [service\_account\_name](#input\_service\_account\_name) | Name of the service account created in the STACKIT project. Override when deploying multiple backplane instances in the same project. | `string` | `"mesh-postgres"` | no |
| <a name="input_trusted_runner_identities"></a> [trusted\_runner\_identities](#input\_trusted\_runner\_identities) | One entry per trusted runner, with the issuer, audience and subject of its tokens. The backplane creates one federated identity provider for each. Pass `trusted_identities` of the [runner-identity module](../../../meshstack/runner-identity). The plan fails for a runner that no version uses. If the same apply changes the runner, the apply fails instead. | <pre>list(object({<br/>    runner_uuid = string<br/>    issuer      = string<br/>    audience    = string<br/>    subject     = string<br/>  }))</pre> | `[]` | no |
| <a name="input_workload_identity_federation"></a> [workload\_identity\_federation](#input\_workload\_identity\_federation) | WIF issuer URL, audience and subject list for the meshStack building block identity provider. The audience defaults to the one meshStack runners use for Azure tokens. | <pre>object({<br/>    issuer   = string<br/>    audience = optional(string, "api://AzureADTokenExchange")<br/>    subjects = list(string)<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_service_account_email"></a> [service\_account\_email](#output\_service\_account\_email) | Email of the STACKIT service account used by the buildingblock provider via WIF. |
<!-- END_TF_DOCS -->
