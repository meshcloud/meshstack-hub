---
name: Azure PostgreSQL
supportedPlatforms:
  - azure
description: Provides an Azure Database for PostgreSQL Flexible Server in a new resource group of the tenant's subscription.
---

# Azure PostgreSQL

This module creates an Azure Database for PostgreSQL Flexible Server in a new resource group. It
defaults to the cheapest setup: the Burstable SKU `B_Standard_B1ms`, 32 GB storage, PostgreSQL 17
and no public network access.

Earlier versions of this module created a Single Server (`azurerm_postgresql_server`). Azure retired
Single Server on 28 March 2025, and azurerm 5.0 removed the resource. Upgrading a building block
created with an earlier version deletes its Single Server and creates an empty Flexible Server. Move
the data to a Flexible Server with the Azure migration service before the upgrade.

The module generates the administrator password at run time and keeps it out of the state and the
outputs. To connect, the application team sets a new password with **Reset password** in the Azure
Portal.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.46.0, < 5.0.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.7.1, < 4.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_postgresql_flexible_server.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/postgresql_flexible_server) | resource |
| [azurerm_resource_group.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_administrator_login"></a> [administrator\_login](#input\_administrator\_login) | Name of the administrator user. | `string` | `"psqladmin"` | no |
| <a name="input_auto_grow_enabled"></a> [auto\_grow\_enabled](#input\_auto\_grow\_enabled) | Grow the storage automatically when it is almost full. | `bool` | `false` | no |
| <a name="input_backup_retention_days"></a> [backup\_retention\_days](#input\_backup\_retention\_days) | Days to keep backups, from 7 to 35. | `number` | `7` | no |
| <a name="input_geo_redundant_backup_enabled"></a> [geo\_redundant\_backup\_enabled](#input\_geo\_redundant\_backup\_enabled) | Store backups in the paired region too. | `bool` | `false` | no |
| <a name="input_location"></a> [location](#input\_location) | The Azure region the server is created in. | `string` | n/a | yes |
| <a name="input_postgresql_server_name"></a> [postgresql\_server\_name](#input\_postgresql\_server\_name) | Name of the PostgreSQL Flexible Server. It is part of the server's DNS name, so it must be unique across Azure. | `string` | n/a | yes |
| <a name="input_postgresql_version"></a> [postgresql\_version](#input\_postgresql\_version) | PostgreSQL major version. | `string` | n/a | yes |
| <a name="input_public_network_access_enabled"></a> [public\_network\_access\_enabled](#input\_public\_network\_access\_enabled) | Allow connections from the internet. Without firewall rules, no client can connect even then. | `bool` | n/a | yes |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Name of the resource group the building block creates for the server. | `string` | n/a | yes |
| <a name="input_sku_name"></a> [sku\_name](#input\_sku\_name) | SKU of the server as tier and size, e.g. `B_Standard_B1ms` (Burstable) or `GP_Standard_D2ds_v5` (General Purpose). | `string` | n/a | yes |
| <a name="input_storage_mb"></a> [storage\_mb](#input\_storage\_mb) | Storage size in MB. Flexible Server accepts 32768, 65536, 131072 and larger powers of two. Storage can only grow. | `number` | n/a | yes |
| <a name="input_subscription_id"></a> [subscription\_id](#input\_subscription\_id) | The Azure subscription the server is created in. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_postgresql_admin_username"></a> [postgresql\_admin\_username](#output\_postgresql\_admin\_username) | The administrator user of the PostgreSQL Flexible Server. |
| <a name="output_postgresql_fqdn"></a> [postgresql\_fqdn](#output\_postgresql\_fqdn) | The fully qualified domain name of the PostgreSQL Flexible Server. |
| <a name="output_postgresql_portal_url"></a> [postgresql\_portal\_url](#output\_postgresql\_portal\_url) | Azure Portal URL of the PostgreSQL Flexible Server. |
| <a name="output_postgresql_server_name"></a> [postgresql\_server\_name](#output\_postgresql\_server\_name) | The name of the PostgreSQL Flexible Server. |
| <a name="output_postgresql_version"></a> [postgresql\_version](#output\_postgresql\_version) | The PostgreSQL major version. |
| <a name="output_resource_group_name"></a> [resource\_group\_name](#output\_resource\_group\_name) | The name of the resource group that holds the server. |
| <a name="output_summary"></a> [summary](#output\_summary) | Markdown summary shown in meshPanel after the run. |
<!-- END_TF_DOCS -->
