# STACKIT Kubernetes Engine (SKE) – Backplane

This module sets up the shared backplane configuration for the STACKIT Kubernetes Engine building
block. It creates a dedicated service account with a Workload Identity Federation (WIF) identity
provider and the permission required to manage SKE clusters in any project under a given folder:

- **`ske.admin`**, on a folder — allows creating, reading, maintaining and deleting SKE clusters and
  their kubeconfigs, in every project below that folder.
- **`additional_project_roles`**, on one named project — whatever else a composition running with
  this identity needs. Empty by default.

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

A composition runs several modules in one Terraform run with one identity, so the identity needs
every role those modules require. `additional_project_roles` is how they get in, and it grants at
**project** scope on `additional_roles_project_id`.

The `stackit-kubernetes` reference architecture is the case this exists for. It runs
`modules/stackit/dns/buildingblock` alongside the SKE module to write each cluster's wildcard record
into a DNS zone the platform team owns. That zone lives in the platform team's own project, outside
the tenant folder, so the identity needs `dns.admin` there:

```hcl
additional_roles_project_id = var.stackit_dns_zone_project_id
additional_project_roles    = ["dns.admin"]
```

One backplane then yields the single service account the whole composition runs as. Without this
grant the DNS module fails with a `403` the moment a tenant orders a cluster.

### Why this grant is project-scoped and `ske.admin` is not

Scope follows what the caller can name at grant time.

`ske.admin` cannot be scoped to a project, because the cluster is created in the STACKIT project of
whichever tenant places the order — the building block takes its `project_id` from
`PLATFORM_TENANT_ID`, and the platform team deploys this backplane long before it knows which
projects tenants will order into. A folder covers all of them.

The DNS zone's project is the opposite: it is a static input the platform team fills in when it
registers the building block definition. Naming it costs nothing and keeps the grant off every other
project. Reach for `folder_id` only when the target genuinely cannot be named.

## Prerequisites

- A STACKIT project where the service account will be created.
- A STACKIT service account with permissions to manage service accounts and folder-level role assignments — and project-level ones when `additional_project_roles` is used.
- The STACKIT folder ID under which the tenant projects live. Projects placed directly under the organization are not covered.
- meshStack WIF issuer and subject from `data.meshstack_integrations.integrations`.
- The STACKIT provider configuration of the caller has to set `experiments = ["iam"]`, because the role assignment resources sit behind that provider experiment.

## Usage

```hcl
module "ske_backplane" {
  source = "./backplane"

  project_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  folder_id  = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

  # Only needed when the composition reaches beyond SKE — for example a shared DNS zone.
  additional_roles_project_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  additional_project_roles    = ["dns.admin"]

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
| [stackit_authorization_project_role_assignment.additional](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/authorization_project_role_assignment) | resource |
| [stackit_service_account.building_block](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/service_account) | resource |
| [stackit_service_account_federated_identity_provider.building_block](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/service_account_federated_identity_provider) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_project_roles"></a> [additional\_project\_roles](#input\_additional\_project\_roles) | Extra STACKIT roles granted to the service account at **project** scope, on<br/>`additional_roles_project_id`.<br/><br/>A composition that runs more than the SKE module with this one identity needs the roles those<br/>other modules require. The `stackit-kubernetes` reference architecture writes each cluster's<br/>wildcard record into a DNS zone the platform team owns, so it passes `["dns.admin"]` with the<br/>zone's project. Project scope is right for that grant because the zone's project is a static<br/>input the platform team fills in when it registers the building block — unlike `ske.admin`, whose<br/>target project is whichever tenant orders a cluster and is therefore unknowable here. | `set(string)` | `[]` | no |
| <a name="input_additional_roles_project_id"></a> [additional\_roles\_project\_id](#input\_additional\_roles\_project\_id) | STACKIT project the roles in `additional_project_roles` are granted on. Name the project a composition needs the identity to reach beyond the tenant folder — for example the project that owns a shared DNS zone. | `string` | `null` | no |
| <a name="input_folder_id"></a> [folder\_id](#input\_folder\_id) | STACKIT folder ID under which the tenant projects live. The service account is granted 'ske.admin' on this folder, which covers every project below it. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | STACKIT project ID where the service account will be created. | `string` | n/a | yes |
| <a name="input_service_account_name"></a> [service\_account\_name](#input\_service\_account\_name) | Name of the service account created in the STACKIT project. Override when deploying multiple backplane instances in the same project. | `string` | `"mesh-ske"` | no |
| <a name="input_workload_identity_federation"></a> [workload\_identity\_federation](#input\_workload\_identity\_federation) | WIF issuer URL and subject list for the meshStack building block identity provider. | <pre>object({<br/>    issuer   = string<br/>    subjects = list(string)<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_service_account_email"></a> [service\_account\_email](#output\_service\_account\_email) | Email of the STACKIT service account used by the buildingblock provider via WIF. |
<!-- END_TF_DOCS -->