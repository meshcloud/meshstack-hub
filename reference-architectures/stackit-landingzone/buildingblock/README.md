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
the hub's network area through an additional `networked` project definition and landing zone, which
set the network area as a static label on the project. Leaving `network` unset (`null`) deploys only
the sandbox landing zone.

It always registers [`modules/stackit/stackit-project-starterkit`](../../../modules/stackit/stackit-project-starterkit)
and [`modules/stackit/service-account`](../../../modules/stackit/service-account). The service
account definition's version ref, the platform ref and the landing zone refs are outputs, so a
composing architecture such as the STACKIT Kubernetes Platform can build on this one.

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
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.6.0, < 4.0.0 |
| <a name="requirement_stackit"></a> [stackit](#requirement\_stackit) | >= 0.99.0, < 1.0.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_network_area_integration"></a> [network\_area\_integration](#module\_network\_area\_integration) | github.com/meshcloud/meshstack-hub//modules/stackit/network-area | main |
| <a name="module_network_integration"></a> [network\_integration](#module\_network\_integration) | github.com/meshcloud/meshstack-hub//modules/stackit/network | main |
| <a name="module_service_account_integration"></a> [service\_account\_integration](#module\_service\_account\_integration) | github.com/meshcloud/meshstack-hub//modules/stackit/service-account | main |
| <a name="module_stackit_integration"></a> [stackit\_integration](#module\_stackit\_integration) | github.com/meshcloud/meshstack-hub//modules/stackit | main |
| <a name="module_stackit_project_starterkit"></a> [stackit\_project\_starterkit](#module\_stackit\_project\_starterkit) | github.com/meshcloud/meshstack-hub//modules/stackit/stackit-project-starterkit | main |

## Resources

| Name | Type |
|------|------|
| [meshstack_building_block.network_area_hub](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block) | resource |
| [meshstack_location.this](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/location) | resource |
| [random_string.playground_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [stackit_resourcemanager_folder.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/resourcemanager_folder) | resource |
| [stackit_resourcemanager_project.foundation](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/resourcemanager_project) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_hub"></a> [hub](#input\_hub) | `git_ref`: meshstack-hub reference used to source the nested foundation, network-area, and network integration modules. `const` so it can be interpolated into the module source at init time.<br/>`bbd_draft`: Forwarded as-is to those nested integrations' own `hub.bbd_draft`, so their building block definition draft state tracks this building block's own release state. | <pre>object({<br/>    git_ref   = optional(string, "main")<br/>    bbd_draft = optional(bool, true)<br/>  })</pre> | <pre>{<br/>  "bbd_draft": true,<br/>  "git_ref": "main"<br/>}</pre> | no |
| <a name="input_meshstack_building_block_id"></a> [meshstack\_building\_block\_id](#input\_meshstack\_building\_block\_id) | Injected by the building block runner. | `string` | n/a | yes |
| <a name="input_network"></a> [network](#input\_network) | Hub-and-spoke address plan, read only when `topology` includes `hub&spoke`. The input is hidden, and so not sent, otherwise. | <pre>object({<br/>    hub_network_area_name            = optional(string, "hub")<br/>    hub_network_ranges               = optional(list(string), ["10.0.0.0/16"])<br/>    hub_transfer_network             = optional(string, "10.1.255.0/24")<br/>    hub_min_prefix_length            = optional(number, 24)<br/>    hub_max_prefix_length            = optional(number, 28)<br/>    hub_default_prefix_length        = optional(number, 28)<br/>    hub_default_nameservers          = optional(list(string), [])<br/>    tenant_network_min_prefix_length = optional(number, 24)<br/>    tenant_network_max_prefix_length = optional(number, 28)<br/>  })</pre> | `null` | no |
| <a name="input_platform_identifier"></a> [platform\_identifier](#input\_platform\_identifier) | Identifier for the STACKIT sandbox platform created in meshStack (letters, digits and dashes only). | `string` | n/a | yes |
| <a name="input_playground_mode"></a> [playground\_mode](#input\_playground\_mode) | Deploy a throwaway platform: the platform identifier gets a random suffix so it does not occupy a name for good, and the landing-zone folder and foundation project are left destroyable. Set to false for a platform that is actually used. A playground platform and the building block definitions it registers are not meant to be published to other workspaces. | `bool` | n/a | yes |
| <a name="input_role_mapping"></a> [role\_mapping](#input\_role\_mapping) | Default mapping from meshStack roles to STACKIT project roles for the nested STACKIT Project integration. Values can be built-in STACKIT roles or custom STACKIT role names. | `map(list(string))` | n/a | yes |
| <a name="input_stackit_org"></a> [stackit\_org](#input\_stackit\_org) | STACKIT organization UUID under which the landing-zone folder, foundation project and tenant projects are created. | `string` | n/a | yes |
| <a name="input_stackit_organization_onboarding_enabled"></a> [stackit\_organization\_onboarding\_enabled](#input\_stackit\_organization\_onboarding\_enabled) | Whether the nested STACKIT Project integration adds meshStack project users to the STACKIT organization before applying project-level role assignments. Disable if organization membership is managed outside this landing zone. | `bool` | n/a | yes |
| <a name="input_stackit_owner_email"></a> [stackit\_owner\_email](#input\_stackit\_owner\_email) | Owner email assigned to the STACKIT resourcemanager folder, the foundation project, and every tenant project the platform creates. | `string` | n/a | yes |
| <a name="input_stackit_service_account_key"></a> [stackit\_service\_account\_key](#input\_stackit\_service\_account\_key) | STACKIT service account key JSON with `resource-manager.admin` on the organization. Used to create the landing-zone folder and foundation project. | `string` | n/a | yes |
| <a name="input_starterkit_approval_policies"></a> [starterkit\_approval\_policies](#input\_starterkit\_approval\_policies) | Run triggers that need an operator's approval before a run of the project starterkit is applied. The defaults are the provider's own, and the provider asserts them whenever the definition sets no policies — so a gate switched on in meshPanel is turned off again by the next run unless it is set here. | <pre>object({<br/>    building_block_creation = bool<br/>    user_input_changes      = bool<br/>    any_input_changes       = bool<br/>    manual_triggers         = bool<br/>    version_upgrade         = bool<br/>  })</pre> | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags forwarded to the nested STACKIT integrations, each map built in the meshPanel form as a list of {key, values} entries.<br/>`landingzone` tags are applied to the created landing zones.<br/>`building_block` tags are applied to the nested building block definitions.<br/>`project` tags are applied to the meshProjects the starterkit creates.<br/>`project_owner_tag_key` names the tag that receives the creator's display name. | <pre>object({<br/>    landingzone           = list(object({ key = string, values = list(string) }))<br/>    building_block        = list(object({ key = string, values = list(string) }))<br/>    project               = list(object({ key = string, values = list(string) }))<br/>    project_owner_tag_key = string<br/>  })</pre> | n/a | yes |
| <a name="input_topology"></a> [topology](#input\_topology) | Landing zone labels to deploy and offer application teams. `sandbox` deploys the sandbox landing zone; `hub&spoke` also provisions the hub-and-spoke networking. The starterkit defaults to `sandbox` when selected, else `hub&spoke`. | `list(string)` | n/a | yes |
| <a name="input_use_global_location"></a> [use\_global\_location](#input\_use\_global\_location) | Use the global location instead of creating a dedicated location for this platform. | `bool` | n/a | yes |
| <a name="input_workspace"></a> [workspace](#input\_workspace) | Identifier of the meshStack workspace that will own the created platform, location, landing zones, and (when networking is enabled) the hub network-area instance. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_foundation_project_id"></a> [foundation\_project\_id](#output\_foundation\_project\_id) | Project ID of the STACKIT foundation project that hosts the landing-zone core assets (the service account used for tenant project creation). |
| <a name="output_foundation_project_url"></a> [foundation\_project\_url](#output\_foundation\_project\_url) | Deep link to the foundation project in the STACKIT portal. |
| <a name="output_landingzone_refs"></a> [landingzone\_refs](#output\_landingzone\_refs) | Landing zone refs of the platform, used to build other platforms on top |
| <a name="output_lz_folder_container_id"></a> [lz\_folder\_container\_id](#output\_lz\_folder\_container\_id) | Container ID of the STACKIT resourcemanager folder created for the landing zone. Tenant projects are created inside this folder. |
| <a name="output_platform_ref"></a> [platform\_ref](#output\_platform\_ref) | Platform ref, used to build other platforms on top |
| <a name="output_service_account_bbd_version_ref"></a> [service\_account\_bbd\_version\_ref](#output\_service\_account\_bbd\_version\_ref) | Version ref of the STACKIT Service Account building block definition this landing zone registered. A composing architecture (e.g. the STACKIT Kubernetes Platform) orders this definition to mint a service account — with project roles and WIF — on a target project, then deploys as that account. |
| <a name="output_starterkit_bbd_version_ref"></a> [starterkit\_bbd\_version\_ref](#output\_starterkit\_bbd\_version\_ref) | Version ref of the STACKIT Project Starterkit definition this architecture registered. The definition is created inside this run, so it cannot be reached through a module output. |
| <a name="output_summary"></a> [summary](#output\_summary) | Summary of the meshStack resources created by this reference architecture. |
<!-- END_TF_DOCS -->
