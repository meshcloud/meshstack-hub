---
name: Azure PostgreSQL Deployment
supportedPlatforms:
  - azure
description: |
  Provides a managed Azure Database for PostgreSQL Flexible Server with scalability, security, and high availability.
---

# Azure PostgreSQL Deployment

This Terraform project deploys a managed Azure Database for PostgreSQL Flexible Server into a dedicated resource group, with sensible defaults for SKU, version, storage, and backups and a security-conscious configuration.

## 🛠 Configuration


<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.64 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.8 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_postgresql_flexible_server.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/postgresql_flexible_server) | resource |
| [azurerm_resource_group.postgresql](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [random_password.psql_admin_password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [random_string.resource_code](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_administrator_login"></a> [administrator\_login](#input\_administrator\_login) | Administrator username for the PostgreSQL Flexible Server. | `string` | `"psqladmin"` | no |
| <a name="input_backup_retention_days"></a> [backup\_retention\_days](#input\_backup\_retention\_days) | Backup retention in days (7-35). | `number` | `7` | no |
| <a name="input_geo_redundant_backup_enabled"></a> [geo\_redundant\_backup\_enabled](#input\_geo\_redundant\_backup\_enabled) | Enable geo-redundant backups. | `bool` | `false` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region where the PostgreSQL Flexible Server is created. | `string` | `"germanywestcentral"` | no |
| <a name="input_postgresql_server_name"></a> [postgresql\_server\_name](#input\_postgresql\_server\_name) | Name prefix for the PostgreSQL Flexible Server. A random 5-character suffix is appended to ensure global uniqueness. Only lowercase letters, numbers and hyphens are allowed. | `string` | n/a | yes |
| <a name="input_postgresql_version"></a> [postgresql\_version](#input\_postgresql\_version) | PostgreSQL major version. | `string` | `"16"` | no |
| <a name="input_public_network_access_enabled"></a> [public\_network\_access\_enabled](#input\_public\_network\_access\_enabled) | Enable public network access. Disabling requires VNet integration (delegated subnet), which is out of scope for this building block. | `bool` | `true` | no |
| <a name="input_sku_name"></a> [sku\_name](#input\_sku\_name) | The SKU name for the PostgreSQL Flexible Server (tier + size, e.g. B\_Standard\_B1ms, GP\_Standard\_D2s\_v3). | `string` | `"B_Standard_B1ms"` | no |
| <a name="input_storage_mb"></a> [storage\_mb](#input\_storage\_mb) | Storage size in MB. Must be one of the sizes supported by Azure Database for PostgreSQL Flexible Server (e.g. 32768, 65536, 131072). | `number` | `32768` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_postgresql_admin_username"></a> [postgresql\_admin\_username](#output\_postgresql\_admin\_username) | The administrator username for the PostgreSQL Flexible Server. |
| <a name="output_postgresql_fqdn"></a> [postgresql\_fqdn](#output\_postgresql\_fqdn) | The fully qualified domain name of the PostgreSQL Flexible Server. |
| <a name="output_postgresql_server_id"></a> [postgresql\_server\_id](#output\_postgresql\_server\_id) | The Azure resource ID of the PostgreSQL Flexible Server. |
| <a name="output_postgresql_server_name"></a> [postgresql\_server\_name](#output\_postgresql\_server\_name) | The name of the PostgreSQL Flexible Server. |
| <a name="output_postgresql_version"></a> [postgresql\_version](#output\_postgresql\_version) | The PostgreSQL major version. |
| <a name="output_psql_admin_password"></a> [psql\_admin\_password](#output\_psql\_admin\_password) | The administrator password for the PostgreSQL Flexible Server. |
| <a name="output_resource_group_name"></a> [resource\_group\_name](#output\_resource\_group\_name) | The name of the resource group in which the PostgreSQL Flexible Server is created. |
<!-- END_TF_DOCS -->
