---
name: STACKIT Hub and Spoke Network
supportedPlatforms:
  - stackit
description: Bootstraps a STACKIT sandbox platform together with a hub-and-spoke network topology, provisioning the hub network area and registering the self-service spoke network building block.
---

This building block composes three Hub modules into a single orderable offering: it sources
[`stackit-sandbox-landingzone`](../../stackit-sandbox-landingzone/buildingblock) to bootstrap the
STACKIT platform, registers [`modules/stackit/network-area`](../../../modules/stackit/network-area)
and immediately orders one instance of it as the hub address plan, and registers
[`modules/stackit/network`](../../../modules/stackit/network) so application teams can self-service
order routed spoke networks inside their STACKIT projects. New STACKIT projects are placed in the
hub's network area via an additional `networked` landing zone tagged with the hub's network area ID.

The user-facing readme is maintained inline in the `readme` field of the
`meshstack_building_block_definition` in
[`../meshstack_integration.tf`](../meshstack_integration.tf).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_meshstack"></a> [meshstack](#requirement\_meshstack) | >= 0.24.0 |
| <a name="requirement_stackit"></a> [stackit](#requirement\_stackit) | >= 0.99.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_foundation"></a> [foundation](#module\_foundation) | github.com/meshcloud/meshstack-hub//reference-architectures/stackit-sandbox-landingzone/buildingblock | main |
| <a name="module_network_area_integration"></a> [network\_area\_integration](#module\_network\_area\_integration) | github.com/meshcloud/meshstack-hub//modules/stackit/network-area | main |
| <a name="module_network_integration"></a> [network\_integration](#module\_network\_integration) | github.com/meshcloud/meshstack-hub//modules/stackit/network | main |

## Resources

| Name | Type |
| ---- | ---- |
| [meshstack_building_block.network_area_hub](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block) | resource |
| [meshstack_landingzone.networked](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/landingzone) | resource |
| [meshstack_landingzone.foundation_default](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/data-sources/landingzone) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_hub"></a> [hub](#input\_hub) | `git_ref`: meshstack-hub reference used to source the nested foundation, network-area, and network integration modules. `const` so it can be interpolated into the module source at init time.<br><br/>`bbd_draft`: Forwarded as-is to those nested integrations' own `hub.bbd_draft`, so their building block definition draft state tracks this building block's own release state. | <pre>object({<br/>    git_ref   = optional(string, "main")<br/>    bbd_draft = optional(bool, true)<br/>  })</pre> | <pre>{<br/>  "bbd_draft": true,<br/>  "git_ref": "main"<br/>}</pre> | no |
| <a name="input_hub_default_nameservers"></a> [hub\_default\_nameservers](#input\_hub\_default\_nameservers) | Default IPv4 nameservers assigned to networks created within the hub network area. | `list(string)` | `[]` | no |
| <a name="input_hub_default_prefix_length"></a> [hub\_default\_prefix\_length](#input\_hub\_default\_prefix\_length) | Default prefix length used for networks created within the hub network area when none is specified. | `number` | `28` | no |
| <a name="input_hub_max_prefix_length"></a> [hub\_max\_prefix\_length](#input\_hub\_max\_prefix\_length) | Maximum prefix length allowed for networks created within the hub network area. | `number` | `28` | no |
| <a name="input_hub_min_prefix_length"></a> [hub\_min\_prefix\_length](#input\_hub\_min\_prefix\_length) | Minimum prefix length allowed for networks created within the hub network area. | `number` | `24` | no |
| <a name="input_hub_network_area_name"></a> [hub\_network\_area\_name](#input\_hub\_network\_area\_name) | Name of the hub STACKIT network area instance. | `string` | `"hub"` | no |
| <a name="input_hub_network_ranges"></a> [hub\_network\_ranges](#input\_hub\_network\_ranges) | List of IPv4 CIDR ranges available to projects within the hub network area. | `list(string)` | <pre>[<br/>  "10.0.0.0/16"<br/>]</pre> | no |
| <a name="input_hub_transfer_network"></a> [hub\_transfer\_network](#input\_hub\_transfer\_network) | IPv4 CIDR range used as the transfer network between the hub network area and connected networks. | `string` | `"10.1.255.0/24"` | no |
| <a name="input_network_area_tag_name"></a> [network\_area\_tag\_name](#input\_network\_area\_tag\_name) | Name of the meshStack landing zone tag whose value is the hub network area's ID. Forwarded to the foundation's nested STACKIT Project integration (so it knows which tag to read) and set on the `networked` landing zone created here (with the hub's network area ID as its value). | `string` | `"StackitNetworkArea"` | no |
| <a name="input_platform_identifier"></a> [platform\_identifier](#input\_platform\_identifier) | Identifier for the STACKIT sandbox platform created in meshStack (letters, digits and dashes only). | `string` | n/a | yes |
| <a name="input_role_mapping"></a> [role\_mapping](#input\_role\_mapping) | Default mapping from meshStack roles to STACKIT project roles for the nested STACKIT Project integration. Values can be built-in STACKIT roles or custom STACKIT role names. | `map(list(string))` | <pre>{<br/>  "admin": [<br/>    "owner"<br/>  ],<br/>  "reader": [<br/>    "reader"<br/>  ],<br/>  "user": [<br/>    "editor"<br/>  ]<br/>}</pre> | no |
| <a name="input_stackit_org"></a> [stackit\_org](#input\_stackit\_org) | STACKIT organization UUID under which the landing-zone folder, backplane project and tenant projects are created. | `string` | n/a | yes |
| <a name="input_stackit_organization_onboarding_enabled"></a> [stackit\_organization\_onboarding\_enabled](#input\_stackit\_organization\_onboarding\_enabled) | Whether the nested STACKIT Project integration adds meshStack project users to the STACKIT organization before applying project-level role assignments. Disable if organization membership is managed outside this landing zone. | `bool` | `true` | no |
| <a name="input_stackit_owner_email"></a> [stackit\_owner\_email](#input\_stackit\_owner\_email) | Owner email assigned to the STACKIT resourcemanager folder and backplane project. | `string` | n/a | yes |
| <a name="input_stackit_service_account_key"></a> [stackit\_service\_account\_key](#input\_stackit\_service\_account\_key) | STACKIT service account key JSON with `resource-manager.admin` on the organization. Used to create the landing-zone folder and backplane project. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags forwarded to the nested foundation, network-area, and network integrations. `landingzone` tags are applied to the created landing zones; `building_block` tags are applied to the nested building block definitions. | <pre>object({<br/>    landingzone    = map(list(string))<br/>    building_block = map(list(string))<br/>  })</pre> | <pre>{<br/>  "building_block": {},<br/>  "landingzone": {}<br/>}</pre> | no |
| <a name="input_tenant_network_max_prefix_length"></a> [tenant\_network\_max\_prefix\_length](#input\_tenant\_network\_max\_prefix\_length) | Maximum allowed IPv4 prefix length for the spoke network BBD's prefix length input, offered to application teams ordering spoke networks. | `number` | `28` | no |
| <a name="input_tenant_network_min_prefix_length"></a> [tenant\_network\_min\_prefix\_length](#input\_tenant\_network\_min\_prefix\_length) | Minimum allowed IPv4 prefix length for the spoke network BBD's prefix length input, offered to application teams ordering spoke networks. | `number` | `24` | no |
| <a name="input_use_global_location"></a> [use\_global\_location](#input\_use\_global\_location) | Use the global location instead of creating a dedicated location for this platform. | `bool` | `false` | no |
| <a name="input_workspace"></a> [workspace](#input\_workspace) | Identifier of the meshStack workspace that will own the created platform, location, landing zones, and the hub network-area instance. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_backplane_project_id"></a> [backplane\_project\_id](#output\_backplane\_project\_id) | Project ID of the STACKIT backplane project that hosts the service account used for tenant project creation. |
| <a name="output_backplane_project_url"></a> [backplane\_project\_url](#output\_backplane\_project\_url) | Deep link to the backplane project in the STACKIT portal. |
| <a name="output_lz_folder_container_id"></a> [lz\_folder\_container\_id](#output\_lz\_folder\_container\_id) | Container ID of the STACKIT resourcemanager folder created for the landing zone. Tenant projects are created inside this folder. |
<!-- END_TF_DOCS -->
