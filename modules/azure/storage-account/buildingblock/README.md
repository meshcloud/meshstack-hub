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
| `account_tier`                      | `SINGLE_SELECT` | `USER_INPUT`  | `Standard` or `Premium` performance tier                                                                               |
| `account_replication_type`          | `SINGLE_SELECT` | `USER_INPUT`  | Replication strategy; its `condition` (`input.account_tier == "Standard"`) hides it for Premium, which always uses LRS |
| `blob_soft_delete_retention_days`   | `INTEGER`       | `USER_INPUT`  | Optional — can be omitted to use the module's 7-day default retention                                                  |
| `business_unit`                     | `CODE`          | `TAG`         | Value of the workspace's `BusinessUnit` tag, read by meshStack rather than typed in by a user                          |
| `network_rules`                     | `JSON`          | `USER_INPUT`  | Filled in through a meshPanel form declared by `json_schema`, reaches Terraform as JSON text                          |

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
| <a name="input_account_replication_type"></a> [account\_replication\_type](#input\_account\_replication\_type) | Replication strategy for the storage account. Only asked for while Account Tier is Standard; Premium storage always uses LRS, so this default is what a Premium deployment actually uses. | `string` | `"LRS"` | no |
| <a name="input_account_tier"></a> [account\_tier](#input\_account\_tier) | Performance tier of the storage account. | `string` | `"Standard"` | no |
| <a name="input_blob_soft_delete_retention_days"></a> [blob\_soft\_delete\_retention\_days](#input\_blob\_soft\_delete\_retention\_days) | Number of days to retain deleted blobs. Optional: when omitted, this default applies. | `number` | `7` | no |
| <a name="input_business_unit"></a> [business\_unit](#input\_business\_unit) | Value of the workspace's BusinessUnit tag, read by meshStack rather than typed in by a user. | `list(string)` | n/a | yes |
| <a name="input_location"></a> [location](#input\_location) | The location/region where the storage account is created. | `string` | n/a | yes |
| <a name="input_network_rules"></a> [network\_rules](#input\_network\_rules) | Network access restrictions for the storage account, filled in through a meshPanel form. | `string` | n/a | yes |
| <a name="input_storage_account_name"></a> [storage\_account\_name](#input\_storage\_account\_name) | The name of the storage account. Must be unique across entire Azure Region, not just within a Subscription. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_account_replication_type"></a> [account\_replication\_type](#output\_account\_replication\_type) | n/a |
| <a name="output_blob_soft_delete_retention_days"></a> [blob\_soft\_delete\_retention\_days](#output\_blob\_soft\_delete\_retention\_days) | n/a |
| <a name="output_network_default_action"></a> [network\_default\_action](#output\_network\_default\_action) | n/a |
| <a name="output_storage_account_id"></a> [storage\_account\_id](#output\_storage\_account\_id) | n/a |
| <a name="output_storage_account_name"></a> [storage\_account\_name](#output\_storage\_account\_name) | n/a |
| <a name="output_storage_account_resource_group"></a> [storage\_account\_resource\_group](#output\_storage\_account\_resource\_group) | n/a |
| <a name="output_storage_account_url"></a> [storage\_account\_url](#output\_storage\_account\_url) | n/a |
| <a name="output_tags"></a> [tags](#output\_tags) | n/a |
<!-- END_TF_DOCS -->
