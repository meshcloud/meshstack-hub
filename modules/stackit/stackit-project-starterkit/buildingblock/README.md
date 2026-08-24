---
name: STACKIT Project Starterkit
supportedPlatforms:
  - stackit
description: Creates a meshProject with a STACKIT project tenant in a selected landing zone, and grants the creator Project Admin.
# Provisions nothing cloud-side: it only calls the meshStack API, using the ephemeral key of its own run.
requiresBackplane: false
---

# STACKIT Project Starterkit

This building block gives an application team a working STACKIT project through one order. It creates a
meshProject, places a meshTenant on the STACKIT platform in the landing zone the team selected, and
grants the creator the Project Admin role on the project.

It provisions nothing in STACKIT itself. The STACKIT project is created by the `STACKIT Project`
building block, which the landing zone attaches to the tenant as a mandatory block, and the spoke
network by the `STACKIT Network` block this module orders inside the tenant. That separation is
deliberate: this module decides *what* to create in meshStack, and the other blocks decide *how* the
STACKIT side is built.

## The block deletes itself

At the end of a successful run this building block deletes itself. The application team is left with
the meshProject, the meshTenant and the spoke network block, and not with a starterkit block they can
do nothing further with.

The definition must therefore set `deletion_mode = "PURGE"`. Under `PURGE` meshStack fabricates a
successful destroy run instead of asking a runner for one, so the delete tears nothing down. Under
`DELETE` the same call would destroy everything the starterkit just created. The two halves belong
together: `terraform_data.self_purge` in this module, and `deletion_mode` in
`meshstack_integration.tf`.

The module is split into a thin top level and `./this` for exactly this reason. Everything the
starterkit creates lives in `./this`, so `depends_on = [module.this]` on the purge resource covers all
of it — including whatever gets added later, without anyone having to extend a resource list.

> ⚠️ **This building block can only be ordered from the panel. Do not order it as code.**
>
> The Terraform provider drops a building block from state as soon as a read reports it deleted, and
> this block deletes itself on every successful run. So `terraform apply` never converges: each apply
> sees an empty state and orders a fresh instance, which creates **another meshProject, meshTenant and
> STACKIT project** with a new random suffix. The abandoned ones are not cleaned up, and a STACKIT
> project that fails to delete stays in `DELETING` forever. An as-code order of this block is a project
> factory, not an idempotent resource.

## Stageless

One order creates one project. There is no dev/prod pair and no stage selection — a team that wants two
environments orders the starterkit twice. This keeps the module free of `for_each` and keeps the tag
configuration a single flat map.

## Configuration the platform team owns

`project_tags` and `owner_tag_key` exist because which meshProject tags are mandatory is a property of
the meshStack instance, not of this module. The module default is an empty map, so **a deployment that
sets no project tags will fail at project creation on any instance with mandatory project tags.** Set
them in the deployment that registers this definition.

`landing_zone_refs` has to carry every landing zone the team may choose, not just one. The definition
builds its select from the map's keys, and a `SINGLE_SELECT` input delivers only the chosen label — so
the module resolves that label against the map itself.

`network_bbd_version_refs` is what decides where a spoke network can be created: it is keyed by the
same labels as `landing_zone_refs`, and only landing zones attached to a network area get an entry. The
`network` user input is *not* the switch — it is ignored wherever there is no entry. That is what lets
`network` carry a usable default, so an order in a networked landing zone gets a subnet with no input
from the application team while an order in a sandbox landing zone still succeeds untouched.

## Ordering the child block is safe

The spoke network lives inside the STACKIT project, which the landing zone's mandatory block creates —
meshStack runs that, not this module. Ordering the network straight after the tenant works because
`meshstack_tenant` does not return until the tenant has a `platform_tenant_id`, and that value is the
mandatory block's output. By the time the network block is ordered, the project exists.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_meshstack"></a> [meshstack](#requirement\_meshstack) | >= 0.24.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.6.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_this"></a> [this](#module\_this) | ./this | n/a |

## Resources

| Name | Type |
|------|------|
| [terraform_data.self_purge](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_add_random_name_suffix"></a> [add\_random\_name\_suffix](#input\_add\_random\_name\_suffix) | Append a five-character random suffix to `name`. The STACKIT project name is the meshProject identifier, so this suffix is what keeps two teams' projects of the same name apart. | `bool` | `true` | no |
| <a name="input_creator"></a> [creator](#input\_creator) | Creator of the starterkit, who is granted the Project Admin role on the created project. | <pre>object({<br/>    type        = string<br/>    identifier  = string<br/>    displayName = string<br/>    username    = optional(string)<br/>    email       = optional(string)<br/>    euid        = optional(string)<br/>  })</pre> | n/a | yes |
| <a name="input_landing_zone"></a> [landing\_zone](#input\_landing\_zone) | Key into `landing_zone_refs`, chosen by the application team from the definition's select. | `string` | n/a | yes |
| <a name="input_landing_zone_refs"></a> [landing\_zone\_refs](#input\_landing\_zone\_refs) | Landing zones the application team can choose from, keyed by the label shown in the select. | <pre>map(object({<br/>    name = string<br/>    kind = string<br/>  }))</pre> | n/a | yes |
| <a name="input_meshstack_building_block_id"></a> [meshstack\_building\_block\_id](#input\_meshstack\_building\_block\_id) | UUID of this building block, injected by the meshStack runner. Used to delete this block at the end of its own run. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Base name for the created meshProject and, through PROJECT\_IDENTIFIER, its STACKIT project. | `string` | n/a | yes |
| <a name="input_network"></a> [network](#input\_network) | Spoke network created inside the project, in landing zones attached to a network area. Named after the project. Set to null to get a project with no network. | <pre>object({<br/>    prefix_length    = optional(number, 25)<br/>    ipv4_nameservers = optional(list(string), [])<br/>  })</pre> | `{}` | no |
| <a name="input_network_bbd_version_refs"></a> [network\_bbd\_version\_refs](#input\_network\_bbd\_version\_refs) | Version refs of the STACKIT Network building block definition, keyed by landing zone label. A landing zone without an entry cannot have a spoke network. | <pre>map(object({<br/>    uuid = string<br/>  }))</pre> | `{}` | no |
| <a name="input_owner_tag_key"></a> [owner\_tag\_key](#input\_owner\_tag\_key) | meshProject tag key that receives the creator's display name. Empty string to set no owner tag. | `string` | `""` | no |
| <a name="input_platform_ref"></a> [platform\_ref](#input\_platform\_ref) | Reference to the meshPlatform the tenant is created on. Required because the meshTenant v4 API references platforms by ref. | <pre>object({<br/>    uuid = string<br/>    kind = string<br/>  })</pre> | n/a | yes |
| <a name="input_project_tags"></a> [project\_tags](#input\_project\_tags) | Tags applied to the created meshProject. Which tags are mandatory is a property of the meshStack instance, so this is set by the platform team. Leaving it empty on an instance with mandatory project tags makes project creation fail. | `map(list(string))` | `{}` | no |
| <a name="input_workspace_identifier"></a> [workspace\_identifier](#input\_workspace\_identifier) | Identifier of the meshStack workspace the created project belongs to. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_network_cidr"></a> [network\_cidr](#output\_network\_cidr) | IPv4 CIDR of the spoke network created inside the project, or `n/a` when the landing zone has no network area. |
| <a name="output_project_identifier"></a> [project\_identifier](#output\_project\_identifier) | Identifier of the created meshProject, which is also the name of its STACKIT project. |
| <a name="output_stackit_project_url"></a> [stackit\_project\_url](#output\_stackit\_project\_url) | Deep link to the created STACKIT project, once the tenant has replicated. |
| <a name="output_summary"></a> [summary](#output\_summary) | Summary of what the starterkit created. |
<!-- END_TF_DOCS -->
