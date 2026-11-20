---
name: STACKIT Project
supportedPlatforms:
  - stackit
description: |
  Creates a new STACKIT project and manages user access permissions with configurable role-based access control. On a networked landing zone, the project is placed in a STACKIT network area and gets a routed network.
---

# STACKIT Project Building Block

This Terraform module provisions a STACKIT project with user access control. meshStack roles from the `users` input are mapped to STACKIT project roles via the configurable `role_mapping` input. When used through the meshStack integration, a pre-run script performs best-effort STACKIT organization onboarding for all assigned users before project-level role assignments are applied and writes a summary that marks users with ✅ when the required organization role is currently assigned.

## Landing zones

One definition serves every landing zone: the building block reads its tenant's landing zone
through a `LANDING_ZONE_IDENTIFIER` input and looks it up in `network_area_ids`. On a match the
project gets the `networkArea` label and orders a `STACKIT Network` building block on the same
tenant, sized by the `network` input, which the definition shows only on those landing zones.

Application teams add the definition from the marketplace to their tenants. meshStack allows one
per tenant (`only_apply_once_per_tenant`), because it reports the project as the tenant's Platform
Tenant ID. The STACKIT platform is hidden from the marketplace, so teams add this building block
rather than order a bare tenant. That applies to a newly created platform only; hide an existing
one in meshPanel.

- The network runs right after this run succeeds, because it reads the project from the tenant's
  Platform Tenant ID. This run does not wait for it.
- `network` is fixed at order time, and later runs leave the network's inputs alone: STACKIT
  replaces a network whose prefix length changes, and the application team's key may not edit the
  network's inputs.
- meshStack refuses the order unless the `STACKIT Network` definition is published to the
  marketplace and its version is released (`hub.bbd_draft = false` on `modules/stackit/network`).
- While the network needs attention, such as a failed run or an approval, every run here fails
  too, a user sync included.
- Do not move a tenant onto or off a networked landing zone. STACKIT sets the network area only at
  project creation, so the re-run fails on the `networkArea` label, after deleting the network
  when the move was off the networked landing zone.

## Project roles

`role_mapping` maps each meshStack role in `users[*].roles` to STACKIT project roles. The
integration's default:

| meshStack role | STACKIT project roles |
|---|---|
| `admin` | `owner` |
| `user` | `editor` |
| `reader` | `reader` |

Values can be built-in or custom STACKIT roles. A user with several meshStack roles gets each
mapped STACKIT role once, and meshStack roles missing from the mapping are ignored.

```hcl
role_mapping = {
  admin   = ["owner"]
  user    = ["editor", "network.admin"]
  reader  = ["reader"]
  auditor = ["reader", "audit-log.viewer"]
}
```

## STACKIT organization membership

STACKIT can reject a project role for a user who is not a member of the organization. With
`stackit_organization_onboarding_enabled` (on by default), the pre-run script first adds every
project user to the organization with `stackit_organization_member_role` (default
`organization.viewer`):

- It is best effort: a failed request is a warning in the run, not a failure. The role
  assignment for that user may then fail.
- It never removes a membership, not even on destroy, because a user may be in several projects.
- The summary marks each user with ✅ once the organization role is assigned, and otherwise says
  what went wrong.

Turn it off where organization membership is managed outside meshStack.

## Parent container per environment

The integration always creates projects in `parent_container_id`. Using the module directly, you
can set `environment` and `parent_container_ids` instead: the project goes to the container of
that environment, or to `parent_container_id` when the environment has none.

```hcl
environment = "production"
parent_container_ids = {
  production  = "organization-prod-123"
  development = "organization-dev-789"
}
```

## Providers

Neither provider block has auth arguments:

- **STACKIT** uses Workload Identity Federation (OIDC token exchange), with no long-lived service
  account key. meshStack injects the federated token file and sets `STACKIT_SERVICE_ACCOUNT_EMAIL`,
  `STACKIT_USE_OIDC` and `STACKIT_FEDERATED_TOKEN_FILE` in the environment.
- **meshStack** uses the ephemeral API key of the run, from `MESHSTACK_ENDPOINT` and
  `MESHSTACK_API_TOKEN`. It needs those on every landing zone, because the provider is configured
  even where no network is ordered.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_external"></a> [external](#requirement\_external) | >= 2.3.0, < 3.0.0 |
| <a name="requirement_meshstack"></a> [meshstack](#requirement\_meshstack) | >= 0.27.1 |
| <a name="requirement_stackit"></a> [stackit](#requirement\_stackit) | >= 0.98.0, < 1.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [meshstack_building_block.network](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block) | resource |
| [stackit_authorization_project_role_assignment.role_assignments](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/authorization_project_role_assignment) | resource |
| [stackit_resourcemanager_project.project](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/resourcemanager_project) | resource |
| [external_external.stackit_users](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_environment"></a> [environment](#input\_environment) | The environment type (production, staging, development). If not set, uses parent\_container\_id directly. | `string` | `null` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Labels to apply to the project. The `networkArea` label is added from `network_area_ids`. | `map(string)` | n/a | yes |
| <a name="input_landing_zone"></a> [landing\_zone](#input\_landing\_zone) | Identifier of the landing zone of the tenant the project is created for. | `string` | n/a | yes |
| <a name="input_network"></a> [network](#input\_network) | Routed network ordered for the project when its landing zone has a network area. An empty `ipv4_nameservers` inherits the network area's default nameservers. | <pre>object({<br/>    prefix_length    = optional(number, 25)<br/>    ipv4_nameservers = optional(list(string), [])<br/>  })</pre> | `{}` | no |
| <a name="input_network_area_ids"></a> [network\_area\_ids](#input\_network\_area\_ids) | STACKIT network area ID per landing zone identifier. A project in one of these landing zones is placed in its network area, and a STACKIT Network building block is ordered for it. | `map(string)` | n/a | yes |
| <a name="input_network_definition_version_ref"></a> [network\_definition\_version\_ref](#input\_network\_definition\_version\_ref) | Version of the STACKIT Network definition the project's network is ordered from. | <pre>object({<br/>    uuid         = string<br/>    content_hash = optional(string)<br/>  })</pre> | `null` | no |
| <a name="input_organization_id"></a> [organization\_id](#input\_organization\_id) | STACKIT organization where project users are looked up before their roles are granted; users STACKIT does not know are skipped and listed in the summary. Needs `iam.member.get` on the organization. Empty grants every user's roles without a lookup. | `string` | `""` | no |
| <a name="input_parent_container_id"></a> [parent\_container\_id](#input\_parent\_container\_id) | The parent container ID (organization or folder) where the project will be created. | `string` | n/a | yes |
| <a name="input_parent_container_ids"></a> [parent\_container\_ids](#input\_parent\_container\_ids) | Parent container IDs for different environments. If environment is set, the corresponding container ID will be used. | <pre>object({<br/>    production  = optional(string)<br/>    staging     = optional(string)<br/>    development = optional(string)<br/>  })</pre> | `{}` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | The name of the StackIt project to create. | `string` | n/a | yes |
| <a name="input_project_owner_email"></a> [project\_owner\_email](#input\_project\_owner\_email) | Email of the initial owner of the created project. STACKIT applies this only at creation, as a<br/>`members` entry with the `owner` role, and ignores any later change. | `string` | n/a | yes |
| <a name="input_role_mapping"></a> [role\_mapping](#input\_role\_mapping) | Maps meshStack roles from `users[*].roles` to STACKIT project roles. Values can be built-in STACKIT roles or custom STACKIT role names. Unknown meshStack roles are ignored. | `map(list(string))` | n/a | yes |
| <a name="input_tenant_uuid"></a> [tenant\_uuid](#input\_tenant\_uuid) | UUID of the meshStack tenant the project is created for. The network building block is ordered on it. | `string` | n/a | yes |
| <a name="input_users"></a> [users](#input\_users) | List of users from the authoritative system. Each user's `roles` are meshStack roles that are mapped to STACKIT project roles via `role_mapping`. | <pre>list(object({<br/>    meshIdentifier = string<br/>    username       = string<br/>    firstName      = string<br/>    lastName       = string<br/>    email          = string<br/>    euid           = string<br/>    roles          = list(string)<br/>  }))</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_container_id"></a> [container\_id](#output\_container\_id) | The user-friendly container ID of the created StackIt project. |
| <a name="output_project_id"></a> [project\_id](#output\_project\_id) | The UUID of the created StackIt project. |
| <a name="output_project_name"></a> [project\_name](#output\_project\_name) | The name of the created StackIt project. |
| <a name="output_project_url"></a> [project\_url](#output\_project\_url) | The deep link URL to access the project in the StackIt portal. |
| <a name="output_summary"></a> [summary](#output\_summary) | Summary of the created project and STACKIT organization membership onboarding for assigned project users. |
<!-- END_TF_DOCS -->