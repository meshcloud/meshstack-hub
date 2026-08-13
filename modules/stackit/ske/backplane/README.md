# STACKIT Kubernetes Engine (SKE) – Backplane

This module sets up the shared backplane configuration for the STACKIT Kubernetes Engine building
block. It creates a dedicated service account with a Workload Identity Federation (WIF) identity
provider and the permission required to manage SKE clusters in any project under a given folder:

- **`ske.admin`** — allows creating, reading, maintaining and deleting SKE clusters and their kubeconfigs.

Authentication uses WIF (OIDC token exchange) — no long-lived service account key is created or stored.

## Why this role

The building block creates a cluster and a kubeconfig, and meshStack deletes the cluster again when
a tenant deletes the building block, so the service account has to cover the full cluster lifecycle.
STACKIT offers three predefined ske roles. `ske.reader` grants three permissions and cannot create
anything. `ske.editor` grants ten of the eleven ske permissions, but not `ske.cluster.delete`, so a
service account with that role creates clusters it can never remove. `ske.admin` adds exactly that
one permission, which makes it the narrowest predefined role that fits. A custom role is the
least-privilege alternative once the exact permission set is stable.

## Why the role is assigned at folder scope

The building block is `TENANT_LEVEL`, so it takes its `project_id` from `PLATFORM_TENANT_ID` and
creates the cluster in the tenant's own STACKIT project. The platform team deploys this backplane
long before it knows which projects tenants will order into, so the role cannot be scoped to a
single project.

`modules/stackit/network/backplane` grants its role at organization scope, but that is not available
here. STACKIT's authorization API offers a different set of roles per resource type, and no ske role
appears on an organization. These three calls establish it, each returning `HTTP/1.1 200 OK`:

```sh
stackit curl https://authorization.api.stackit.cloud/v2/organization/<organization-id>/roles
# resourceType=organization, 76 roles, no ske role

stackit curl https://authorization.api.stackit.cloud/v2/folder/<folder-id>/roles
# resourceType=folder, 184 roles, including ske.admin, ske.editor and ske.reader

stackit curl https://authorization.api.stackit.cloud/v2/project/<project-id>/roles
# resourceType=project, 182 roles, including the same three ske roles
```

The organization response is not filtered down to organization-management roles, so the absence is
a real one rather than an artifact of the call: `iaas.network.admin` is present at organization
scope, which is the role `modules/stackit/network/backplane` grants there. An organization role
assignment for `ske.admin` therefore fails at apply. Do not move this grant back.

A folder covers every project below it, so folder scope keeps the property that makes organization
scope attractive: the platform team grants the role once, and every project a tenant later receives
is covered. Grant the role on the folder that holds the tenant projects. When tenant projects are
spread over several folders, deploy one backplane instance per folder and override
`service_account_name`.

The same reasoning applies to `modules/stackit/postgresflex/backplane` and
`modules/stackit/model-serving/backplane`, which grant their roles at folder scope as well.

## Compositions that also write DNS records

This backplane grants `ske.admin` and nothing else. The `stackit-kubernetes` reference architecture
runs `modules/stackit/dns/buildingblock` with the same service account to write each cluster's
wildcard record into a shared DNS zone. That zone usually lives in the platform team's own project,
which is outside the tenant folder, so the platform team has to grant `dns.admin` on the zone project
to this service account separately.

## Prerequisites

- A STACKIT project where the service account will be created.
- A STACKIT service account with permissions to manage service accounts and folder-level role assignments.
- The STACKIT folder ID under which the tenant projects live. Projects placed directly under the organization are not covered.
- meshStack WIF issuer and subject from `data.meshstack_integrations.integrations`.
- The STACKIT provider configuration of the caller has to set `experiments = ["iam"]`, because the role assignment resources sit behind that provider experiment.

## Usage

```hcl
module "ske_backplane" {
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
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_stackit"></a> [stackit](#requirement\_stackit) | >= 0.110.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [stackit_authorization_folder_role_assignment.ske_admin](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/authorization_folder_role_assignment) | resource |
| [stackit_service_account.building_block](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/service_account) | resource |
| [stackit_service_account_federated_identity_provider.building_block](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/service_account_federated_identity_provider) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_folder_id"></a> [folder\_id](#input\_folder\_id) | STACKIT folder ID under which the tenant projects live. The service account is granted 'ske.admin' on this folder, which covers every project below it. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | STACKIT project ID where the service account will be created. | `string` | n/a | yes |
| <a name="input_service_account_name"></a> [service\_account\_name](#input\_service\_account\_name) | Name of the service account created in the STACKIT project. Override when deploying multiple backplane instances in the same project. | `string` | `"mesh-ske"` | no |
| <a name="input_workload_identity_federation"></a> [workload\_identity\_federation](#input\_workload\_identity\_federation) | WIF issuer URL and subject list for the meshStack building block identity provider. | <pre>object({<br/>    issuer   = string<br/>    subjects = list(string)<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_service_account_email"></a> [service\_account\_email](#output\_service\_account\_email) | Email of the STACKIT service account used by the buildingblock provider via WIF. |
<!-- END_TF_DOCS -->