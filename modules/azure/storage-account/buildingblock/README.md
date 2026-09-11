---
name: Azure Storage Account
supportedPlatforms:
  - azure
description: |
  Provides an Azure Storage Account as a highly scalable, durable, and secure container that groups together a set of Azure Storage services.
---

# Azure Storage Account

This Terraform module provisions an Azure Storage Account along with necessary role assignments.


## Requirements
- Terraform `>= 1.0`
- AzureRM Provider `>= 4.18.0`

## Providers

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.18.0"
    }
  }
}

provider "azurerm" {
  features {}
}
```

## Input Types

| Input                              | Type            | Assignment    | Description                                                                                                          |
|-------------------------------------|-----------------|---------------|------------------------------------------------------------------------------------------------------------------------|
| `storage_account_name`              | `STRING`        | `USER_INPUT`  | Name prefix for the storage account, 3–19 lowercase letters/numbers                                                    |
| `blob_soft_delete_retention_days`   | `INTEGER`       | `USER_INPUT`  | Optional — can be omitted to use the module's 7-day default retention                                                  |
| `restrict_network_access`           | `BOOLEAN`       | `USER_INPUT`  | Whether to restrict network access; enabling it reveals the Network Rules input below                                 |
| `network_rules`                     | `JSON`          | `USER_INPUT`  | Shown only when `restrict_network_access` is true, filled in through a meshPanel form declared by `json_schema`, reaches Terraform as a typed object |
| `tag_name`                          | `CODE`          | `STATIC`      | Internal: the workspace tag name that `tag_value` resolves, set from the integration's `workspace_tag_to_copy`; only declared when that's non-null |
| `tag_value`                         | `CODE`          | `TAG`         | Only declared when `workspace_tag_to_copy` is set; value of the workspace tag named by `tag_name`, read by meshStack rather than typed in by a user |

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_azuread"></a> [azuread](#requirement\_azuread) | >= 3.8, < 4.0.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.64, < 5.0.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.8, < 4.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_resource_group.storage_account_rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_storage_account.storage_account](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account) | resource |
| [random_string.resource_code](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |
| [azurerm_subscription.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subscription) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_blob_soft_delete_retention_days"></a> [blob\_soft\_delete\_retention\_days](#input\_blob\_soft\_delete\_retention\_days) | Number of days to retain deleted blobs. Optional: when omitted, this default applies. | `number` | `7` | no |
| <a name="input_location"></a> [location](#input\_location) | The location/region where the storage account is created. | `string` | n/a | yes |
| <a name="input_network_rules"></a> [network\_rules](#input\_network\_rules) | Network access restrictions applied when restrict\_network\_access is true, filled in through a meshPanel form. | <pre>object({<br/>    bypass                     = optional(list(string), ["AzureServices"])<br/>    ip_rules                   = optional(list(string), [])<br/>    virtual_network_subnet_ids = optional(list(string), [])<br/>  })</pre> | `{}` | no |
| <a name="input_restrict_network_access"></a> [restrict\_network\_access](#input\_restrict\_network\_access) | Whether to restrict network access to the storage account. When false, the storage account allows traffic from any network and network\_rules is ignored. | `bool` | `false` | no |
| <a name="input_storage_account_name"></a> [storage\_account\_name](#input\_storage\_account\_name) | The name of the storage account. Must be unique across entire Azure Region, not just within a Subscription. | `string` | n/a | yes |
| <a name="input_tag_name"></a> [tag\_name](#input\_tag\_name) | Name of the workspace tag applied to the storage account, also used as the Azure tag key. Set from outside via the integration's workspace\_tag\_to\_copy; null copies no tag. | `string` | `null` | no |
| <a name="input_tag_value"></a> [tag\_value](#input\_tag\_value) | Value of the workspace tag named by tag\_name, resolved by meshStack. Null when tag\_name is unset or the workspace has no value for it. | `list(string)` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_blob_soft_delete_retention_days"></a> [blob\_soft\_delete\_retention\_days](#output\_blob\_soft\_delete\_retention\_days) | n/a |
| <a name="output_network_default_action"></a> [network\_default\_action](#output\_network\_default\_action) | n/a |
| <a name="output_storage_account_id"></a> [storage\_account\_id](#output\_storage\_account\_id) | n/a |
| <a name="output_storage_account_name"></a> [storage\_account\_name](#output\_storage\_account\_name) | n/a |
| <a name="output_storage_account_resource_group"></a> [storage\_account\_resource\_group](#output\_storage\_account\_resource\_group) | n/a |
| <a name="output_storage_account_url"></a> [storage\_account\_url](#output\_storage\_account\_url) | n/a |
| <a name="output_tags"></a> [tags](#output\_tags) | n/a |
<!-- END_TF_DOCS -->
