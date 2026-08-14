# STACKIT DNS – Backplane

This module sets up the shared backplane configuration for the STACKIT DNS building block. It
creates a dedicated service account with a Workload Identity Federation (WIF) identity provider and
grants it the roles the building block needs:

- **`dns.admin`**, on the projects named in `zone_project_ids` — create and delete DNS zones and
  record sets in each of them. Or, when no project can be named, on the folder in `folder_id`,
  which covers every project below it.
- **`iam.member-admin`**, on the organization — assign the `dns.admin` role to the DNS service
  account the building block creates in the zone's project.

Authentication uses WIF (OIDC token exchange) — no long-lived service account key is created or
stored for the building block identity itself.

This backplane exists for the meshStack-ordered path, where meshStack federates a token into the run
and `../buildingblock` authenticates with it. A composition that brings its own STACKIT credentials
does not deploy this module at all: it configures the provider itself and sources
`../buildingblock/zone`, the submodule that declares none. Its own credential then needs the same
`dns.admin` reach described below, plus whatever role it uses to create service accounts.
`reference-architectures/stackit-landingzone` takes that route.

## How one identity reaches one or two STACKIT projects

On the usual path the building block writes into a single project: the zone, its records and the
DNS service account all live there. On the delegation path, which only works for a customer-owned
domain, it also writes the NS record into the platform team's own project, which owns the parent
zone.

It reaches both with a single identity and a single provider configuration, because STACKIT
credentials are not bound to a project. A service account belongs to the project it was created in,
but every resource carries its own `project_id`, and access is decided by the role assignments the
account holds on the target resource. So there is no second provider, no second credential, and no
credential handed from one project to the other.

What makes it work is the scope of the role assignment.

## Project scope where the projects are known, folder scope where they are not

Scope follows what the caller can name when the backplane is deployed.

**`zone_project_ids` is the default path.** Name the projects that own the zones and the service
account is granted `dns.admin` on exactly those. Two cases make the projects knowable:

- A composition fixes the zone's project as a static input. `reference-architectures/stackit-kubernetes`
  does this — the platform team owns one zone in its own project and fills that project in when it
  registers the building block definition.
- The delegation path. The parent zone's project is `delegation.parent_zone_project_id` on the
  building block, so it is named there too.

**`folder_id` is the fallback, for one case only.** The `TENANT_LEVEL` building block definition in
`../meshstack_integration.tf` takes its `project_id` from `PLATFORM_TENANT_ID`, so the zone lands in
whichever tenant project places the order, and the platform team registers the definition long
before it knows which those are. A folder covers every project below it, so it keeps the property
that makes a wide scope attractive: grant once, and every project a tenant later receives is
covered. **Every project involved then has to live under that folder** — a parent zone kept outside
it needs its project listed in `zone_project_ids` as well.

Set at least one of the two. Setting both is fine and is what a mixed deployment needs.

## Why not organization scope, in either case

The sibling backplanes grant their role at organization scope, and `modules/stackit/network/backplane`
is right to do so, but that does not generalise. STACKIT's authorization API offers a different set
of roles per resource type, and **no dns role appears on an organization**. Assigning `dns.admin`
there fails. These three calls establish it, each returning `HTTP/1.1 200 OK`:

```sh
stackit curl https://authorization.api.stackit.cloud/v2/organization/<organization-id>/roles
# resourceType=organization, 76 roles, no dns role at all

stackit curl https://authorization.api.stackit.cloud/v2/folder/<folder-id>/roles
# resourceType=folder, 184 roles, including dns.admin and dns.reader

stackit curl https://authorization.api.stackit.cloud/v2/project/<project-id>/roles
# resourceType=project, 182 roles, including dns.admin and dns.reader
```

The organization response is not filtered down to organization-management roles, so the absence is a
real one rather than an artifact of the call: `iaas.network.admin`, `organization.admin`,
`iam.member-admin` and `resource-manager.admin` are all present at organization scope.

`iam.member-admin` is one of the 76, which is why this module still assigns that one on the
organization. When tenant projects are spread over several folders and none of them can be named,
deploy one backplane instance per folder and override `service_account_name`.

## The one permission this module does not grant

The building block also creates a service account and a service account key, which cert-manager and
ExternalDNS authenticate with. Creating a service account is an IAM operation, and this module does
not grant it, because the right role depends on how far you want the identity to reach.

The role list above carries `iam.service-account-creator`, `iam.service-account-key-admin` and
`iam.service-account-admin`, and all three exist at organization, folder and project scope. Pick the
one your organization uses and pass it through `additional_organization_roles`. List the roles a
resource offers with the calls above.

Two ways out if you would rather not widen the identity:

- Set `dns_service_account_enabled = false` on the building block. It then creates the zone and its
  records only, and the platform team supplies the DNS key by hand.
- Define a custom role that carries the service account permissions and nothing else, then list it
  in `additional_organization_roles`.

## What the DNS key can reach

`dns.admin` is a project role. The key the building block hands to cert-manager and ExternalDNS can
therefore write every record in every zone of the project the zone lives in. Under a free STACKIT
subdomain that is unavoidable, because such a domain admits exactly one zone at exactly one label
and every cluster below it shares that zone. Give tenants a domain you own if you need a real
boundary between them.

## Provider requirements

`stackit_authorization_project_role_assignment`, which the building block uses, sits behind the
STACKIT provider's `iam` experiment. The building block's own `provider.tf` sets it. The root
configuration that applies **this** backplane has to set it as well, because a backplane module
carries no provider block:

```hcl
provider "stackit" {
  default_region = "eu01"
  experiments    = ["iam"]
}
```

## Prerequisites

- A STACKIT project where the service account will be created.
- A STACKIT service account with permissions to manage service accounts, organization-level role
  assignments, and project-level or folder-level role assignments depending on which scope you use.
- Either the STACKIT projects that own the zones, or the folder ID under which every project
  involved lives. Projects placed directly under the organization are not covered by a folder.
- The STACKIT organization ID.
- meshStack WIF issuer and subject from `data.meshstack_integrations.integrations`.

## Usage

```hcl
module "dns_backplane" {
  source = "./backplane"

  project_id      = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  organization_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

  # Name the zones' projects where you can. Fall back to folder_id only when the zone lands in
  # whichever tenant project places the order.
  zone_project_ids = ["xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"]
  folder_id        = null

  # The role your organization uses to create service accounts in tenant projects.
  additional_organization_roles = []

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
| [stackit_authorization_folder_role_assignment.dns_admin](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/authorization_folder_role_assignment) | resource |
| [stackit_authorization_organization_role_assignment.additional](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/authorization_organization_role_assignment) | resource |
| [stackit_authorization_organization_role_assignment.member_admin](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/authorization_organization_role_assignment) | resource |
| [stackit_authorization_project_role_assignment.dns_admin](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/authorization_project_role_assignment) | resource |
| [stackit_service_account.building_block](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/service_account) | resource |
| [stackit_service_account_federated_identity_provider.building_block](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/service_account_federated_identity_provider) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_organization_roles"></a> [additional\_organization\_roles](#input\_additional\_organization\_roles) | Extra STACKIT roles granted to the service account at organization scope. Use this for the role your organization uses to create service accounts and service account keys in tenant projects, which the building block needs for the DNS credential. See backplane/README.md. | `list(string)` | `[]` | no |
| <a name="input_folder_id"></a> [folder\_id](#input\_folder\_id) | STACKIT folder ID under which the zones' projects live. The service account is granted `dns.admin`<br/>on this folder, which covers every project below it.<br/><br/>This is the fallback for the one case where no project can be named: the `TENANT_LEVEL` building<br/>block definition takes its `project_id` from `PLATFORM_TENANT_ID`, so the zone lands in whichever<br/>tenant project places the order. Prefer `zone_project_ids` whenever the projects are known.<br/>STACKIT offers no dns role at organization scope, so a folder is the widest scope available for it. | `string` | `null` | no |
| <a name="input_organization_id"></a> [organization\_id](#input\_organization\_id) | STACKIT organization ID the folder lives under. The service account is granted 'iam.member-admin' here, which lets the building block assign 'dns.admin' to the DNS service account it creates. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | STACKIT project ID where the service account will be created. | `string` | n/a | yes |
| <a name="input_service_account_name"></a> [service\_account\_name](#input\_service\_account\_name) | Name of the service account created in the STACKIT project. Override when deploying multiple backplane instances in the same project. | `string` | `"mesh-dns"` | no |
| <a name="input_workload_identity_federation"></a> [workload\_identity\_federation](#input\_workload\_identity\_federation) | WIF issuer URL and subject list for the meshStack building block identity provider. | <pre>object({<br/>    issuer   = string<br/>    subjects = list(string)<br/>  })</pre> | n/a | yes |
| <a name="input_zone_project_ids"></a> [zone\_project\_ids](#input\_zone\_project\_ids) | STACKIT projects that own the zones the building block writes into. The service account is granted<br/>`dns.admin` on each of them, at **project** scope.<br/><br/>Use this wherever the projects are knowable when the backplane is deployed — a composition that<br/>fixes the zone project as a static input, or the delegation path, where the parent zone's project<br/>is named by `delegation.parent_zone_project_id`. Fall back to `folder_id` only when they are not. | `set(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_service_account_email"></a> [service\_account\_email](#output\_service\_account\_email) | Email of the STACKIT service account used by the buildingblock provider via WIF. |
<!-- END_TF_DOCS -->