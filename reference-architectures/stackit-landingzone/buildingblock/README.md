---
name: STACKIT Landing Zone
supportedPlatforms:
  - stackit
description: Onboards a STACKIT sandbox platform into meshStack (location, resourcemanager folder and STACKIT Project platform with its default landing zone), and optionally layers on a hub-and-spoke network topology.
---

This building block bootstraps a complete STACKIT sandbox platform integration inside a meshStack
workspace. It creates a meshStack location, a dedicated STACKIT resourcemanager folder and a
foundation project hosting the landing-zone core assets, then sources the
[`modules/stackit`](../../../modules/stackit) project integration to provision the STACKIT Project
platform together with its default landing zone.

When a `network` object is supplied, it additionally composes two more Hub modules into the same
offering: it registers [`modules/stackit/network-area`](../../../modules/stackit/network-area) and
immediately orders one instance of it as the hub address plan, and registers
[`modules/stackit/network`](../../../modules/stackit/network) so application teams can self-service
order routed spoke networks inside their STACKIT projects. New STACKIT projects are then placed in
the hub's network area via an additional `networked` landing zone tagged with the hub's network
area ID. Leaving `network` unset (`null`) deploys only the sandbox landing zone.

It authenticates to STACKIT with a service account key you paste as a secret input. You also
provide the STACKIT organization UUID, owner email, nested integration tags and default role mapping
as user inputs. The service account needs `resource-manager.admin` on the organization. The nested
integrations are pinned to the same `git_ref` as this building block's implementation.

The user-facing readme is maintained inline in the `readme` field of the
`meshstack_building_block_definition` in
[`../meshstack_integration.tf`](../meshstack_integration.tf).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_meshstack"></a> [meshstack](#requirement\_meshstack) | >= 0.24.0 |
| <a name="requirement_stackit"></a> [stackit](#requirement\_stackit) | >= 0.99.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_network_area_integration"></a> [network\_area\_integration](#module\_network\_area\_integration) | github.com/meshcloud/meshstack-hub//modules/stackit/network-area | main |
| <a name="module_network_integration"></a> [network\_integration](#module\_network\_integration) | github.com/meshcloud/meshstack-hub//modules/stackit/network | main |
| <a name="module_stackit_integration"></a> [stackit\_integration](#module\_stackit\_integration) | github.com/meshcloud/meshstack-hub//modules/stackit | main |

## Resources

| Name | Type |
|------|------|
| [meshstack_building_block.network_area_hub](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block) | resource |
| [meshstack_location.this](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/location) | resource |
| [stackit_resourcemanager_folder.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/resourcemanager_folder) | resource |
| [stackit_resourcemanager_project.foundation](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/resourcemanager_project) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_hub"></a> [hub](#input\_hub) | `git_ref`: meshstack-hub reference used to source the nested foundation, network-area, and network integration modules. `const` so it can be interpolated into the module source at init time.<br/>`bbd_draft`: Forwarded as-is to those nested integrations' own `hub.bbd_draft`, so their building block definition draft state tracks this building block's own release state. | <pre>object({<br/>    git_ref   = optional(string, "main")<br/>    bbd_draft = optional(bool, true)<br/>  })</pre> | <pre>{<br/>  "bbd_draft": true,<br/>  "git_ref": "main"<br/>}</pre> | no |
| <a name="input_network"></a> [network](#input\_network) | Optional hub-and-spoke network topology. Leave unset (null) to deploy only the sandbox landing zone. When set, additionally provisions a shared hub network area with the given address plan (`hub_*` fields), registers the self-service spoke `STACKIT Network` building block (`tenant_network_*` prefix bounds), and adds a dedicated `networked` STACKIT Project building block definition and landing zone whose projects are placed in the hub network area. | <pre>object({<br/>    hub_network_area_name            = optional(string, "hub")<br/>    hub_network_ranges               = optional(list(string), ["10.0.0.0/16"])<br/>    hub_transfer_network             = optional(string, "10.1.255.0/24")<br/>    hub_min_prefix_length            = optional(number, 24)<br/>    hub_max_prefix_length            = optional(number, 28)<br/>    hub_default_prefix_length        = optional(number, 28)<br/>    hub_default_nameservers          = optional(list(string), [])<br/>    tenant_network_min_prefix_length = optional(number, 24)<br/>    tenant_network_max_prefix_length = optional(number, 28)<br/>  })</pre> | `null` | no |
| <a name="input_platform_identifier"></a> [platform\_identifier](#input\_platform\_identifier) | Identifier for the STACKIT sandbox platform created in meshStack (letters, digits and dashes only). | `string` | n/a | yes |
| <a name="input_role_mapping"></a> [role\_mapping](#input\_role\_mapping) | Default mapping from meshStack roles to STACKIT project roles for the nested STACKIT Project integration. Values can be built-in STACKIT roles or custom STACKIT role names. | `map(list(string))` | n/a | yes |
| <a name="input_stackit_org"></a> [stackit\_org](#input\_stackit\_org) | STACKIT organization UUID under which the landing-zone folder, foundation project and tenant projects are created. | `string` | n/a | yes |
| <a name="input_stackit_organization_onboarding_enabled"></a> [stackit\_organization\_onboarding\_enabled](#input\_stackit\_organization\_onboarding\_enabled) | Whether the nested STACKIT Project integration adds meshStack project users to the STACKIT organization before applying project-level role assignments. Disable if organization membership is managed outside this landing zone. | `bool` | n/a | yes |
| <a name="input_stackit_owner_email"></a> [stackit\_owner\_email](#input\_stackit\_owner\_email) | Owner email assigned to the STACKIT resourcemanager folder and foundation project. | `string` | n/a | yes |
| <a name="input_stackit_service_account_key"></a> [stackit\_service\_account\_key](#input\_stackit\_service\_account\_key) | STACKIT service account key JSON with `resource-manager.admin` on the organization. Used to create the landing-zone folder and foundation project. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags forwarded to the nested STACKIT integrations. `landingzone` tags are applied to the created landing zones; `building_block` tags are applied to the nested building block definitions. | <pre>object({<br/>    landingzone    = map(list(string))<br/>    building_block = map(list(string))<br/>  })</pre> | n/a | yes |
| <a name="input_use_global_location"></a> [use\_global\_location](#input\_use\_global\_location) | Use the global location instead of creating a dedicated location for this platform. | `bool` | n/a | yes |
| <a name="input_workspace"></a> [workspace](#input\_workspace) | Identifier of the meshStack workspace that will own the created platform, location, landing zones, and (when networking is enabled) the hub network-area instance. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_foundation_project_id"></a> [foundation\_project\_id](#output\_foundation\_project\_id) | Project ID of the STACKIT foundation project that hosts the landing-zone core assets (the service account used for tenant project creation). |
| <a name="output_foundation_project_url"></a> [foundation\_project\_url](#output\_foundation\_project\_url) | Deep link to the foundation project in the STACKIT portal. |
| <a name="output_lz_folder_container_id"></a> [lz\_folder\_container\_id](#output\_lz\_folder\_container\_id) | Container ID of the STACKIT resourcemanager folder created for the landing zone. Tenant projects are created inside this folder. |
| <a name="output_summary"></a> [summary](#output\_summary) | Summary of the meshStack resources created by this reference architecture. |
<!-- END_TF_DOCS -->
