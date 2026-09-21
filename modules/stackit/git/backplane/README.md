# STACKIT Git Instance — Backplane

Provisions the automation identity the STACKIT Git Instance building block runs as, using **Workload
Identity Federation** (no long-lived key).

It creates:

- a **STACKIT service account** in an existing project (`project_id` — e.g. a foundation project),
- a **federated identity provider** trusting the meshStack building block's OIDC subject, and
- **folder-level role assignments** (`roles`, default `git.admin`).

The roles are granted on the landing-zone **folder** on purpose: the project the Git instance is
created in is provisioned at order time and does not exist when this backplane runs, so the grant
has to inherit down to it.

`git.admin` is the narrow role, not a placeholder. Both the role's contents and its availability at
folder scope were read from the live authorization API
(`GET https://authorization.api.stackit.cloud/v2/folder/<folder_id>/roles`). It carries:

```
git.flavor.list
git.instance.create / get / list / update / delete
git.instance.authentication-source.create / get / list / update / delete
git.instance.users.create / get / update / delete
git.runner.create / get / delete
```

— everything this module needs and nothing outside STACKIT Git. `git.reader` is the read-only
variant. Two of those permissions matter beyond today's module: `git.instance.users.create` and
`git.instance.update` are exactly what minting the Forgejo token automatically requires, so this
backplane is already scoped for that path (see the TODO in `../buildingblock/main.tf`).

`git.admin` is also **complete**: no service-enablement permission is needed alongside it.
`cloud.stackit.git` is among the services STACKIT enables by default on a new project — measured on
four projects, three of them landing-zone-created foundations, via
`GET https://service-enablement.api.stackit.cloud/v2/projects/<project_id>/regions/<region>/services`
— so creating the first instance never has to flip the service on. That is the difference from the
SKE cluster backplane, which runs as `editor` because `cloud.stackit.ske` **is** disabled by default
and enabling it needs `service-enablement.service-state.edit`, a permission no service-specific role
carries.

## Permissions required to apply

Whoever applies this backplane needs to create a service account in `project_id` and assign
folder-level roles on `folder_id` (folder owner / `resource-manager.admin` + `iam.member-admin`).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_stackit"></a> [stackit](#requirement\_stackit) | >= 0.98.0, < 1.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [stackit_authorization_folder_role_assignment.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/authorization_folder_role_assignment) | resource |
| [stackit_service_account.building_block](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/service_account) | resource |
| [stackit_service_account_federated_identity_provider.building_block](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/service_account_federated_identity_provider) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_folder_id"></a> [folder\_id](#input\_folder\_id) | STACKIT resource-manager folder the service account is granted roles on. Roles are assigned on the folder so they are inherited by every project inside it (the Git instance's project is provisioned at order time inside that folder). This is the folder's `folder_id`, not its container\_id. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | STACKIT project the automation service account is created in. This is an existing project (e.g. a foundation project) — NOT the project the Git instance ends up in, which may not exist yet when the backplane is applied. | `string` | n/a | yes |
| <a name="input_roles"></a> [roles](#input\_roles) | Roles granted to the service account on the folder so it can create Git instances in the projects<br/>inside it. `git.admin` is the narrow role and is assignable at folder scope — both verified<br/>against the live authorization API (`GET https://authorization.api.stackit.cloud/v2/folder/<folder_id>/roles`).<br/>It carries instance create/get/list/update/delete, the instance users and authentication-source<br/>calls, the runners and the flavor list, and nothing outside STACKIT Git. `git.reader` exists for a<br/>read-only variant.<br/><br/>No service-enablement permission is needed on top: `cloud.stackit.git` is among the services<br/>STACKIT enables by default on a new project, measured across four projects including three<br/>landing-zone-created foundations (`GET https://service-enablement.api.stackit.cloud/v2/projects/<project_id>/regions/<region>/services`).<br/>Creating the first instance therefore never has to enable the service, which is why this module<br/>needs nothing beyond `git.admin` while the SKE cluster backplane needs `editor` — SKE is disabled<br/>by default, STACKIT Git is not. | `list(string)` | <pre>[<br/>  "git.admin"<br/>]</pre> | no |
| <a name="input_service_account_name"></a> [service\_account\_name](#input\_service\_account\_name) | Name of the STACKIT automation service account. STACKIT caps this at 20 characters. | `string` | `"mesh-stackit-git"` | no |
| <a name="input_workload_identity_federation"></a> [workload\_identity\_federation](#input\_workload\_identity\_federation) | WIF issuer URL and subject list for the meshStack building block identity provider. | <pre>object({<br/>    issuer   = string<br/>    subjects = list(string)<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_service_account_email"></a> [service\_account\_email](#output\_service\_account\_email) | Email of the STACKIT service account the buildingblock provider authenticates as via WIF. |
<!-- END_TF_DOCS -->
