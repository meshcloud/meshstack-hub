---
name: Azure Landing Zone
supportedPlatforms:
  - azure
description: Onboards an Azure Subscription platform into meshStack on top of an existing Enterprise-Scale management group hierarchy, creates Corp/Online/Sandbox landing zones, and registers the budget-alert, storage-account and spoke-network building blocks.
---

This is the Terraform for the [Azure Landing Zone reference architecture](../README.md). It composes
the Azure platform integration and three Hub building blocks into a single onboarding run.

It assumes the Azure **management group hierarchy already exists** (a parent "Landing Zones"
management group with Corp, Online and Sandbox management groups beneath it) and a central network
**hub** vnet is already in place. The run then:

- sources [`modules/azure`](../../../modules/azure) to register the **Azure Subscription** platform
  and one landing zone per archetype (Corp, Online, Sandbox), each pointing at its management group;
- sources [`modules/azure/budget-alert`](../../../modules/azure/budget-alert),
  [`modules/azure/storage-account`](../../../modules/azure/storage-account) and
  [`modules/azure/spoke-network`](../../../modules/azure/spoke-network), each of which creates its
  own backplane (a User-Assigned Managed Identity federated to the building block definition, with a
  deploy role scoped to the landing-zones management group) and registers the building block
  definition.

## Applying

This is a one-time platform onboarding building block, ordered once in meshStack. meshStack runs it
as the privileged **bootstrap identity** provisioned by [`../bootstrap`](../bootstrap) — a UAMI
federated to the building block definition, so the run authenticates via workload identity
federation (no stored secret). The `azurerm`/`azuread` providers pick up the `ARM_*` OIDC
environment meshStack injects for that identity. (For local development you can also apply this
directly with an equivalently privileged `az login`.)

The composed building blocks are then individually orderable by application teams; the budget-alert
and storage-account building blocks currently target the platform subscription
(`azure_platform_subscription_id`), while the spoke-network building block deploys into each
ordering tenant's own subscription.

The user-facing readme is maintained inline in the `readme` field of the
`meshstack_building_block_definition` in
[`../meshstack_integration.tf`](../meshstack_integration.tf).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_azuread"></a> [azuread](#requirement\_azuread) | >= 3.8 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.64 |
| <a name="requirement_meshstack"></a> [meshstack](#requirement\_meshstack) | >= 0.24.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.6.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_azure_platform"></a> [azure\_platform](#module\_azure\_platform) | github.com/meshcloud/meshstack-hub//modules/azure | main |
| <a name="module_budget_alert"></a> [budget\_alert](#module\_budget\_alert) | github.com/meshcloud/meshstack-hub//modules/azure/budget-alert | main |
| <a name="module_es_policies"></a> [es\_policies](#module\_es\_policies) | ./modules/es-policies | n/a |
| <a name="module_hub_network"></a> [hub\_network](#module\_hub\_network) | github.com/meshcloud/meshstack-hub//modules/azure/hub-network | main |
| <a name="module_management_groups"></a> [management\_groups](#module\_management\_groups) | ./modules/management-groups | n/a |
| <a name="module_spoke_network"></a> [spoke\_network](#module\_spoke\_network) | github.com/meshcloud/meshstack-hub//modules/azure/spoke-network | main |
| <a name="module_storage_account"></a> [storage\_account](#module\_storage\_account) | github.com/meshcloud/meshstack-hub//modules/azure/storage-account | main |

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_resource_group.foundation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [meshstack_building_block.hub](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block) | resource |
| [meshstack_location.this](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/location) | resource |
| [random_string.playground_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_azure_backplane_subscription_id"></a> [azure\_backplane\_subscription\_id](#input\_azure\_backplane\_subscription\_id) | Optional bare GUID of the subscription where the spoke-network backplane identity is created. Defaults to azure\_platform\_subscription\_id. Typically the hub subscription so the automation identity lives in a stable, platform-owned place. | `string` | `null` | no |
| <a name="input_azure_connectivity_subscription_id"></a> [azure\_connectivity\_subscription\_id](#input\_azure\_connectivity\_subscription\_id) | Bare GUID of the connectivity subscription where the Azure Hub Network backplane identity lives and, when foundation.hub is set, the hub vnet and firewall are created. | `string` | n/a | yes |
| <a name="input_azure_hub_resource_group_name"></a> [azure\_hub\_resource\_group\_name](#input\_azure\_hub\_resource\_group\_name) | Name of the resource group that contains an existing hub vnet spoke networks peer into. Leave null when foundation.hub creates the hub. | `string` | `null` | no |
| <a name="input_azure_hub_scope"></a> [azure\_hub\_scope](#input\_azure\_hub\_scope) | Full resource path where the spoke-network backplane's hub-peering role is granted: a management group or subscription path containing an existing hub vnet. Leave null when foundation.hub creates the hub. | `string` | `null` | no |
| <a name="input_azure_hub_subscription_id"></a> [azure\_hub\_subscription\_id](#input\_azure\_hub\_subscription\_id) | Bare GUID of the subscription hosting an existing central hub vnet that spoke networks peer into. Leave null when foundation.hub creates the hub. | `string` | `null` | no |
| <a name="input_azure_hub_vnet_name"></a> [azure\_hub\_vnet\_name](#input\_azure\_hub\_vnet\_name) | Name of an existing hub vnet spoke networks peer into. Leave null when foundation.hub creates the hub. | `string` | `null` | no |
| <a name="input_azure_location"></a> [azure\_location](#input\_azure\_location) | Azure region where the building block backplane resource groups and identities are created. | `string` | `"germanywestcentral"` | no |
| <a name="input_azure_management_groups"></a> [azure\_management\_groups](#input\_azure\_management\_groups) | Enterprise-Scale management group hierarchy (Landing Zones → Corp/Online/Sandbox, plus<br/>Connectivity) under `parent_management_group_id`, with names prefixed by `name_prefix`. The<br/>bootstrap step already created these; this building block adopts them via `import` blocks and<br/>manages them. Pre-configured STATIC by the platform team at registration (parent = bootstrap scope,<br/>same name\_prefix as the bootstrap) — end users don't specify it. | <pre>object({<br/>    parent_management_group_id = string<br/>    name_prefix                = optional(string, "")<br/>    landing_zones_display_name = optional(string, "Landing Zones")<br/>    corp_display_name          = optional(string, "Corp")<br/>    online_display_name        = optional(string, "Online")<br/>    sandbox_display_name       = optional(string, "Sandbox")<br/>    connectivity_display_name  = optional(string, "Connectivity")<br/>  })</pre> | n/a | yes |
| <a name="input_azure_platform_subscription_id"></a> [azure\_platform\_subscription\_id](#input\_azure\_platform\_subscription\_id) | Bare GUID of a platform-owned subscription. The azurerm provider targets it, the budget-alert and storage-account backplanes are created in it, and (as written) those two building blocks deploy their resources into it. | `string` | n/a | yes |
| <a name="input_azure_subscription_owner_object_ids"></a> [azure\_subscription\_owner\_object\_ids](#input\_azure\_subscription\_owner\_object\_ids) | Optional explicit subscription owner object IDs. If null, the applying principal is used. | `list(string)` | `null` | no |
| <a name="input_azure_subscription_provisioning"></a> [azure\_subscription\_provisioning](#input\_azure\_subscription\_provisioning) | Azure subscription provisioning model — set exactly one:<br/>`pre_provisioned` (default): meshStack assigns subscriptions from a pool of existing ones whose name starts with `unused_subscription_name_prefix` (default `unused-`). No MCA service principal is created.<br/>`customer_agreement`: meshStack creates subscriptions via the given MCA billing scope. | <pre>object({<br/>    pre_provisioned = optional(object({<br/>      unused_subscription_name_prefix = optional(string, "unused-")<br/>    }))<br/>    customer_agreement = optional(object({<br/>      billing_account_name = string<br/>      billing_profile_name = string<br/>      invoice_section_name = string<br/>    }))<br/>  })</pre> | <pre>{<br/>  "pre_provisioned": {}<br/>}</pre> | no |
| <a name="input_azure_tenant_id"></a> [azure\_tenant\_id](#input\_azure\_tenant\_id) | Azure Entra tenant ID. Used as the ARM tenant for the building block backplanes. | `string` | n/a | yes |
| <a name="input_foundation"></a> [foundation](#input\_foundation) | Optional Azure-side foundation this architecture provisions on top of the meshStack wiring. Leave<br/>null to only register the platform, landing zones and building blocks. (The management group<br/>hierarchy is configured separately via `azure_management_groups`.)<br/>`hub`: when set, orders one Azure Hub Network instance — a hub vnet (with optional firewall) in the<br/>connectivity subscription — that spoke networks peer into. The Azure Hub Network building block<br/>itself is always registered.<br/>`policies`: when true, assigns curated Enterprise-Scale policies to the Corp/Online/Sandbox<br/>management groups.<br/>`resource_groups`: extra platform-owned resource groups (name => { location }) created in the<br/>platform subscription. | <pre>object({<br/>    hub = optional(object({<br/>      address_space           = optional(string, "10.0.0.0/22")<br/>      hub_vnet_name           = optional(string, "hub-vnet")<br/>      hub_resource_group_name = optional(string, "hub-network")<br/>      create_gateway_subnet   = optional(bool, true)<br/>      deploy_firewall         = optional(bool, false)<br/>      firewall_sku_tier       = optional(string, "Standard")<br/>    }))<br/>    policies        = optional(bool, false)<br/>    resource_groups = optional(map(object({ location = string })), {})<br/>  })</pre> | `null` | no |
| <a name="input_hub"></a> [hub](#input\_hub) | `git_ref`: meshstack-hub reference used to source the nested platform, budget-alert, storage-account and spoke-network integration modules. `const` so it can be interpolated into the module source at init time.<br/>`bbd_draft`: Forwarded as-is to those nested integrations' own `hub.bbd_draft`, so their building block definition draft state tracks this architecture's own release state. | <pre>object({<br/>    git_ref   = optional(string, "main")<br/>    bbd_draft = optional(bool, true)<br/>  })</pre> | <pre>{<br/>  "bbd_draft": true,<br/>  "git_ref": "main"<br/>}</pre> | no |
| <a name="input_platform_identifier"></a> [platform\_identifier](#input\_platform\_identifier) | Identifier for the Azure platform created in meshStack (letters, digits and dashes only). Landing zone names are derived as `<platform_identifier>-<archetype>`. | `string` | n/a | yes |
| <a name="input_playground_mode"></a> [playground\_mode](#input\_playground\_mode) | Deploy a throwaway platform: the platform identifier gets a random suffix so it does not occupy a name for good across the meshStack instance. Set to false for a platform that is actually used. A playground platform and the building block definitions it registers are not meant to be published to other workspaces. | `bool` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags forwarded to the nested integrations.<br/>`landingzone` tags are applied to the created landing zones.<br/>`building_block` tags are applied to the nested building block definitions (budget alert, storage account, spoke network). | <pre>object({<br/>    landingzone    = map(list(string))<br/>    building_block = map(list(string))<br/>  })</pre> | n/a | yes |
| <a name="input_use_global_location"></a> [use\_global\_location](#input\_use\_global\_location) | Use the global meshStack location instead of creating a dedicated location for this platform. | `bool` | n/a | yes |
| <a name="input_workspace"></a> [workspace](#input\_workspace) | Identifier of the meshStack workspace that will own the created platform, location, landing zones and building block definitions. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_budget_alert_bbd"></a> [budget\_alert\_bbd](#output\_budget\_alert\_bbd) | Reference to the Azure Budget Alert building block definition registered by this architecture. |
| <a name="output_hub_network_bbd"></a> [hub\_network\_bbd](#output\_hub\_network\_bbd) | Reference to the Azure Hub Network building block definition registered by this architecture, or null when foundation.hub is not set. |
| <a name="output_landingzone_names"></a> [landingzone\_names](#output\_landingzone\_names) | meshStack landing zone names created per archetype. |
| <a name="output_landingzone_refs"></a> [landingzone\_refs](#output\_landingzone\_refs) | References to the created landing zones, keyed by archetype (`corp`, `online`, `sandbox`). |
| <a name="output_platform_ref"></a> [platform\_ref](#output\_platform\_ref) | Reference to the meshPlatform this architecture creates, for compositions that create meshTenants (subscriptions) on it. |
| <a name="output_spoke_network_bbd"></a> [spoke\_network\_bbd](#output\_spoke\_network\_bbd) | Reference to the Azure Spoke Network building block definition registered by this architecture. |
| <a name="output_storage_account_bbd"></a> [storage\_account\_bbd](#output\_storage\_account\_bbd) | Reference to the Azure Storage Account building block definition registered by this architecture. |
| <a name="output_summary"></a> [summary](#output\_summary) | Summary of the meshStack resources created by this reference architecture. |
<!-- END_TF_DOCS -->
