# STACKIT PostgreSQL Flex – Backplane

This module sets up the shared backplane configuration for the STACKIT PostgreSQL Flex building
block. It creates a dedicated service account with a Workload Identity Federation (WIF) identity
provider and the permission required to create PostgreSQL Flex instances in any project under a
given folder:

- **`postgres-flex.admin`** — allows creating and managing PostgreSQL Flex instances, databases and users.

Authentication uses WIF (OIDC token exchange) — no long-lived service account key is created or stored.

## Why this role

The building block creates an instance, a database and a user, and its building block definition
sets `deletion_mode = "DELETE"`, so the service account also has to remove all three again.
`postgres-flex.editor` can create them but grants none of the delete permissions, so
`postgres-flex.admin` is the narrowest predefined role that covers the full lifecycle. A custom role
is the least-privilege alternative once the exact permission set is stable.

Note the spelling. The Terraform resources and the CLI namespace write the service as one word,
`postgresflex`, but the role name uses a hyphen: `postgres-flex.admin`.

## Why the role is assigned at folder scope

The building block is `TENANT_LEVEL`, so it takes its `project_id` from `PLATFORM_TENANT_ID` and
creates the instance in the tenant's own STACKIT project. The platform team deploys this backplane
long before it knows which projects tenants will order into, so the role cannot be scoped to a
single project.

`modules/stackit/network/backplane` grants its role at organization scope, but that is not available
here. STACKIT's authorization API offers a different set of roles per resource type, and no
postgres-flex role appears on an organization. These three calls establish it, each returning
`HTTP/1.1 200 OK`:

```sh
stackit curl https://authorization.api.stackit.cloud/v2/organization/<organization-id>/roles
# resourceType=organization, 76 roles, no postgres-flex role

stackit curl https://authorization.api.stackit.cloud/v2/folder/<folder-id>/roles
# resourceType=folder, 184 roles, including postgres-flex.admin, .editor, .reader,
# .user-admin and .metrics-reader

stackit curl https://authorization.api.stackit.cloud/v2/project/<project-id>/roles
# resourceType=project, 182 roles, including the same five postgres-flex roles
```

The organization response is not filtered down to organization-management roles, so the absence is
a real one rather than an artifact of the call: `iaas.network.admin` is present at organization
scope, which is the role `modules/stackit/network/backplane` grants there. An organization role
assignment for `postgres-flex.admin` therefore fails at apply. Do not move this grant back.

A folder covers every project below it, so folder scope keeps the property that makes organization
scope attractive: the platform team grants the role once, and every project a tenant later receives
is covered. Grant the role on the folder that holds the tenant projects. When tenant projects are
spread over several folders, deploy one backplane instance per folder and override
`service_account_name`.

The same reasoning applies to `modules/stackit/model-serving/backplane`, which grants
`model-serving.editor` at folder scope.

## Prerequisites

- A STACKIT project where the service account will be created.
- A STACKIT service account with permissions to manage service accounts and folder-level role assignments.
- The STACKIT folder ID under which the tenant projects live. Projects placed directly under the organization are not covered.
- meshStack WIF issuer and subject from `data.meshstack_integrations.integrations`.
- The STACKIT provider configuration of the caller has to set `experiments = ["iam"]`, because the role assignment resources sit behind that provider experiment.

## Usage

```hcl
module "postgresflex_backplane" {
  source = "./backplane"

  project_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  folder_id  = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

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
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_stackit"></a> [stackit](#requirement\_stackit) | >= 0.110.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [stackit_authorization_folder_role_assignment.postgres_flex_admin](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/authorization_folder_role_assignment) | resource |
| [stackit_service_account.building_block](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/service_account) | resource |
| [stackit_service_account_federated_identity_provider.building_block](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/service_account_federated_identity_provider) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_folder_id"></a> [folder\_id](#input\_folder\_id) | STACKIT folder ID under which the tenant projects live. The service account is granted 'postgres-flex.admin' on this folder, which covers every project below it. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | STACKIT project ID where the service account will be created. | `string` | n/a | yes |
| <a name="input_service_account_name"></a> [service\_account\_name](#input\_service\_account\_name) | Name of the service account created in the STACKIT project. Override when deploying multiple backplane instances in the same project. | `string` | `"mesh-postgresflex"` | no |
| <a name="input_workload_identity_federation"></a> [workload\_identity\_federation](#input\_workload\_identity\_federation) | WIF issuer URL and subject list for the meshStack building block identity provider. | <pre>object({<br/>    issuer   = string<br/>    subjects = list(string)<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_service_account_email"></a> [service\_account\_email](#output\_service\_account\_email) | Email of the STACKIT service account used by the buildingblock provider via WIF. |
<!-- END_TF_DOCS -->
