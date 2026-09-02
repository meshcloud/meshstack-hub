---
name: Azure Landing Zone
supportedPlatforms:
  - azure
description: Onboards an Azure Subscription platform into meshStack on top of an existing Enterprise-Scale management group hierarchy, creates Corp/Online/Sandbox landing zones, and registers the budget-alert, storage-account and spoke-network building blocks.
---

This is the Terraform for the [Azure Landing Zone reference architecture](../README.md). It composes
the Azure platform integration and three Hub building blocks into a single onboarding run.

It **creates** the Enterprise-Scale management group hierarchy (a parent "Landing Zones" management
group with Corp, Online and Sandbox beneath it, plus Connectivity) under a parent management group
the platform engineer provides, and assumes a central network **hub** vnet is already in place. The
run then:

- creates the management group hierarchy and sources [`modules/azure`](../../../modules/azure) to
  register the **Azure Subscription** platform and one landing zone per archetype (Corp, Online,
  Sandbox), each pointing at its management group;
- sources [`modules/azure/budget-alert`](../../../modules/azure/budget-alert),
  [`modules/azure/storage-account`](../../../modules/azure/storage-account) and
  [`modules/azure/spoke-network`](../../../modules/azure/spoke-network), each of which creates its
  own backplane (a User-Assigned Managed Identity federated to the building block definition, with a
  deploy role scoped to the landing-zones management group) and registers the building block
  definition.

## Applying

This is a one-time platform onboarding building block, ordered once in meshStack. meshStack runs it
as a **service principal the platform engineer supplies when ordering** (`azure_client_id`,
`azure_client_secret`, `azure_tenant_id` — the secret is a sensitive input, the Azure equivalent of
the STACKIT service account key). That principal needs **Owner** on the parent management group and
the Microsoft Graph app roles `Application.ReadWrite.All`, `Directory.Read.All` and
`AppRoleAssignment.ReadWrite.All`. The `azurerm`/`azuread` providers are configured directly from
those inputs (see [`provider.tf`](provider.tf)) — no bootstrap identity, no separate apply.

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
| <a name="input_assign_policies"></a> [assign\_policies](#input\_assign\_policies) | Assign curated Enterprise-Scale policies to the Corp/Online/Sandbox management groups (Corp locked down, Online region-restricted, Sandbox audit-only). | `bool` | `true` | no |
| <a name="input_azure_backplane_subscription_id"></a> [azure\_backplane\_subscription\_id](#input\_azure\_backplane\_subscription\_id) | Optional bare GUID of the subscription where the spoke-network backplane identity is created. Defaults to azure\_platform\_subscription\_id. Typically the hub subscription so the automation identity lives in a stable, platform-owned place. | `string` | `null` | no |
| <a name="input_azure_client_id"></a> [azure\_client\_id](#input\_azure\_client\_id) | Client ID of the service principal this run authenticates as. Needs Owner on the management group scope and Microsoft Graph app roles (Application.ReadWrite.All, Directory.Read.All, AppRoleAssignment.ReadWrite.All) to create the management groups, platform service principals and backplane identities. | `string` | n/a | yes |
| <a name="input_azure_client_secret"></a> [azure\_client\_secret](#input\_azure\_client\_secret) | Client secret of the service principal this run authenticates as. The Azure equivalent of the STACKIT service account key — reused on every run and rotatable from the meshStack UI. | `string` | n/a | yes |
| <a name="input_azure_connectivity_subscription_id"></a> [azure\_connectivity\_subscription\_id](#input\_azure\_connectivity\_subscription\_id) | Bare GUID of the connectivity subscription where the Azure Hub Network backplane identity lives and, when provision_hub is set, the hub vnet and firewall are created. | `string` | n/a | yes |
| <a name="input_azure_location"></a> [azure\_location](#input\_azure\_location) | Azure region where the building block backplane resource groups and identities are created. | `string` | `"germanywestcentral"` | no |
| <a name="input_azure_management_groups"></a> [azure\_management\_groups](#input\_azure\_management\_groups) | Enterprise-Scale management group hierarchy (Landing Zones → Corp/Online/Sandbox, plus<br/>Connectivity) this run creates under `parent_management_group_id` (an existing management group or<br/>the tenant ID), with names prefixed by `name_prefix` to keep them unique across the tenant. | <pre>object({<br/>    parent_management_group_id = string<br/>    name_prefix                = optional(string, "")<br/>    landing_zones_display_name = optional(string, "Landing Zones")<br/>    corp_display_name          = optional(string, "Corp")<br/>    online_display_name        = optional(string, "Online")<br/>    sandbox_display_name       = optional(string, "Sandbox")<br/>    connectivity_display_name  = optional(string, "Connectivity")<br/>  })</pre> | n/a | yes |
| <a name="input_azure_platform_subscription_id"></a> [azure\_platform\_subscription\_id](#input\_azure\_platform\_subscription\_id) | Bare GUID of a platform-owned subscription. The azurerm provider targets it, the budget-alert and storage-account backplanes are created in it, and (as written) those two building blocks deploy their resources into it. | `string` | n/a | yes |
| <a name="input_azure_subscription_owner_object_ids"></a> [azure\_subscription\_owner\_object\_ids](#input\_azure\_subscription\_owner\_object\_ids) | Optional explicit subscription owner object IDs. If null, the applying principal is used. | `list(string)` | `null` | no || <a name="input_azure_tenant_id"></a> [azure\_tenant\_id](#input\_azure\_tenant\_id) | Azure Entra tenant ID. Used to authenticate the providers and as the ARM tenant for the building block backplanes. | `string` | n/a | yes |
| <a name="input_creator"></a> [creator](#input\_creator) | The user who ordered this architecture, injected by meshStack. Their display name is written to the landing zones' owner tag (see `tags.owner_tag_key`). | <pre>object({<br/>    type        = string<br/>    identifier  = string<br/>    displayName = string<br/>    username    = optional(string)<br/>    email       = optional(string)<br/>    euid        = optional(string)<br/>  })</pre> | n/a | yes |
| <a name="input_customer_agreement"></a> [customer\_agreement](#input\_customer\_agreement) | Customer-agreement (MCA) model: the billing scope meshStack creates subscriptions under. Required when subscription\_provisioning\_model is customer\_agreement. | <pre>object({<br/>    billing_account_name = string<br/>    billing_profile_name = string<br/>    invoice_section_name = string<br/>  })</pre> | `null` | no |
| <a name="input_foundation_resource_groups"></a> [foundation\_resource\_groups](#input\_foundation\_resource\_groups) | Extra platform-owned resource groups created in the platform subscription. | <pre>list(object({<br/>    name     = string<br/>    location = string<br/>  }))</pre> | `[]` | no |
| <a name="input_hub"></a> [hub](#input\_hub) | `git_ref`: meshstack-hub reference used to source the nested platform, budget-alert, storage-account and spoke-network integration modules. `const` so it can be interpolated into the module source at init time.<br/>`bbd_draft`: Forwarded as-is to those nested integrations' own `hub.bbd_draft`, so their building block definition draft state tracks this architecture's own release state. | <pre>object({<br/>    git_ref   = optional(string, "main")<br/>    bbd_draft = optional(bool, true)<br/>  })</pre> | <pre>{<br/>  "bbd_draft": true,<br/>  "git_ref": "main"<br/>}</pre> | no |
| <a name="input_hub_network"></a> [hub\_network](#input\_hub\_network) | Hub vnet settings, used when provision\_hub is true. The vnet and resource-group names here are also the ones spoke networks peer into. | <pre>object({<br/>    address_space           = optional(string, "10.0.0.0/22")<br/>    hub_vnet_name           = optional(string, "hub-vnet")<br/>    hub_resource_group_name = optional(string, "hub-network")<br/>    create_gateway_subnet   = optional(bool, true)<br/>    deploy_firewall         = optional(bool, false)<br/>    firewall_sku_tier       = optional(string, "Standard")<br/>  })</pre> | `{}` | no |
| <a name="input_platform_identifier"></a> [platform\_identifier](#input\_platform\_identifier) | Identifier for the Azure platform created in meshStack (letters, digits and dashes only). Landing zone names are derived as `<platform_identifier>-<archetype>`. | `string` | n/a | yes |
| <a name="input_playground_mode"></a> [playground\_mode](#input\_playground\_mode) | Deploy a throwaway platform: the platform identifier gets a random suffix so it does not occupy a name for good across the meshStack instance. Set to false for a platform that is actually used. A playground platform and the building block definitions it registers are not meant to be published to other workspaces. | `bool` | n/a | yes |
| <a name="input_pre_provisioned"></a> [pre\_provisioned](#input\_pre\_provisioned) | Pre-provisioned model: meshStack assigns subscriptions from existing ones whose name starts with `unused_subscription_name_prefix`. | <pre>object({<br/>    unused_subscription_name_prefix = optional(string, "unused-")<br/>  })</pre> | <pre>{<br/>  "unused_subscription_name_prefix": "unused-"<br/>}</pre> | no |
| <a name="input_provision_hub"></a> [provision\_hub](#input\_provision\_hub) | Provision a central hub vnet (via the Azure Hub Network building block) in the connectivity subscription for spoke networks to peer into. When false, spoke networks peer into an existing hub. | `bool` | `false` | no |
| <a name="input_subscription_provisioning_model"></a> [subscription\_provisioning\_model](#input\_subscription\_provisioning\_model) | How meshStack gets Azure subscriptions: `pre_provisioned` (assign from an existing pool) or `customer_agreement` (create via MCA billing). | `string` | `"pre_provisioned"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags forwarded to the nested integrations, each built in the meshPanel form as a list of {key, values} entries.<br/>`landingzone` tags are applied to the created landing zones.<br/>`building_block` tags are applied to the nested building block definitions (budget alert, storage account, spoke network).<br/>`owner_tag_key` names the landing-zone tag that receives the creator's display name (empty to set none). | <pre>object({<br/>    landingzone    = list(object({ key = string, values = list(string) }))<br/>    building_block = list(object({ key = string, values = list(string) }))<br/>    owner_tag_key  = optional(string, "")<br/>  })</pre> | n/a | yes |
| <a name="input_use_global_location"></a> [use\_global\_location](#input\_use\_global\_location) | Use the global meshStack location instead of creating a dedicated location for this platform. | `bool` | n/a | yes |
| <a name="input_workspace"></a> [workspace](#input\_workspace) | Identifier of the meshStack workspace that will own the created platform, location, landing zones and building block definitions. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_budget_alert_bbd"></a> [budget\_alert\_bbd](#output\_budget\_alert\_bbd) | Reference to the Azure Budget Alert building block definition registered by this architecture. |
| <a name="output_hub_network_bbd"></a> [hub\_network\_bbd](#output\_hub\_network\_bbd) | Reference to the Azure Hub Network building block definition registered by this architecture, or null when provision_hub is false. |
| <a name="output_landingzone_names"></a> [landingzone\_names](#output\_landingzone\_names) | meshStack landing zone names created per archetype. |
| <a name="output_landingzone_refs"></a> [landingzone\_refs](#output\_landingzone\_refs) | References to the created landing zones, keyed by archetype (`corp`, `online`, `sandbox`). |
| <a name="output_platform_ref"></a> [platform\_ref](#output\_platform\_ref) | Reference to the meshPlatform this architecture creates, for compositions that create meshTenants (subscriptions) on it. |
| <a name="output_spoke_network_bbd"></a> [spoke\_network\_bbd](#output\_spoke\_network\_bbd) | Reference to the Azure Spoke Network building block definition registered by this architecture. |
| <a name="output_storage_account_bbd"></a> [storage\_account\_bbd](#output\_storage\_account\_bbd) | Reference to the Azure Storage Account building block definition registered by this architecture. |
| <a name="output_summary"></a> [summary](#output\_summary) | Summary of the meshStack resources created by this reference architecture. |
<!-- END_TF_DOCS -->
