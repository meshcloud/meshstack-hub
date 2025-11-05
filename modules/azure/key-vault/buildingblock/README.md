---
name: Azure Key Vault
supportedPlatforms:
  - azure
description: |
  Provides an Azure Key Vault for secure storage and management of secrets, keys, and certificates with RBAC authorization, optional private endpoint support, and hub connectivity.
---

# Azure Key Vault

This Terraform module provisions an Azure Key Vault with support for both public and private networking configurations, including private endpoints with DNS integration and hub VNet peering.

## Features

- **RBAC Authorization**: Uses Azure RBAC for secure access control
- **Private Endpoint Support**: Optional private endpoint with VNet integration
- **Hub Connectivity**: Bidirectional VNet peering for hub-spoke topologies
- **Private DNS Integration**: Automatic or custom Private DNS zone configuration
- **Security Defaults**: Soft delete and purge protection enabled by default
- **Flexible Networking**: Support for new or existing VNets and subnets
- **Tagging Support**: Custom tags for resource organization

## Requirements
- Terraform `>= 1.3.0`
- AzureRM Provider `~> 4.18.0`

## Deployment Scenarios

This module supports 4 deployment scenarios:

1. **New VNet + Hub Peering**: Creates new VNet with private endpoint and bidirectional peering to hub
2. **Existing Shared VNet**: Deploys private endpoint into existing VNet (no peering)
3. **Private Isolated**: Creates private Key Vault without hub connectivity
4. **Completely Public**: Public Key Vault accessible from internet

See [APP_TEAM_README.md](./APP_TEAM_README.md) for detailed usage examples and configuration.

## Providers

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.18.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.3"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azurerm" {
  alias = "hub"
  features {}
}
```

## Network Architecture

### Private Endpoint with Hub Peering
```
┌─────────────────┐         ┌──────────────────┐
│   Hub VNet      │◄────────┤  Key Vault VNet  │
│                 │  Peering│                  │
│  - On-premises  │─────────►  - Private EP    │
│  - VPN Gateway  │         │  - DNS Zone      │
└─────────────────┘         └──────────────────┘
                                     │
                            ┌────────┴────────┐
                            │   Key Vault     │
                            │  Private IP     │
                            └─────────────────┘
```

### DNS Resolution
- **Private DNS Zone**: `privatelink.vaultcore.azure.net`
- **Private Endpoint Subresource**: `vault`
- **Automatic DNS**: System-managed or custom DNS zone

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_azuread"></a> [azuread](#requirement\_azuread) | 3.1.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | 4.18.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | 3.6.3 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_key_vault.key_vault](https://registry.terraform.io/providers/hashicorp/azurerm/4.18.0/docs/resources/key_vault) | resource |
| [azurerm_private_dns_zone.key_vault_dns](https://registry.terraform.io/providers/hashicorp/azurerm/4.18.0/docs/resources/private_dns_zone) | resource |
| [azurerm_private_dns_zone_virtual_network_link.key_vault_dns_link](https://registry.terraform.io/providers/hashicorp/azurerm/4.18.0/docs/resources/private_dns_zone_virtual_network_link) | resource |
| [azurerm_private_endpoint.key_vault_pe](https://registry.terraform.io/providers/hashicorp/azurerm/4.18.0/docs/resources/private_endpoint) | resource |
| [azurerm_resource_group.key_vault](https://registry.terraform.io/providers/hashicorp/azurerm/4.18.0/docs/resources/resource_group) | resource |
| [azurerm_subnet.pe_subnet](https://registry.terraform.io/providers/hashicorp/azurerm/4.18.0/docs/resources/subnet) | resource |
| [azurerm_virtual_network.vnet](https://registry.terraform.io/providers/hashicorp/azurerm/4.18.0/docs/resources/virtual_network) | resource |
| [azurerm_virtual_network_peering.hub_to_key_vault](https://registry.terraform.io/providers/hashicorp/azurerm/4.18.0/docs/resources/virtual_network_peering) | resource |
| [azurerm_virtual_network_peering.key_vault_to_hub](https://registry.terraform.io/providers/hashicorp/azurerm/4.18.0/docs/resources/virtual_network_peering) | resource |
| [random_string.resource_code](https://registry.terraform.io/providers/hashicorp/random/3.6.3/docs/resources/string) | resource |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/4.18.0/docs/data-sources/client_config) | data source |
| [azurerm_resource_group.hub_rg](https://registry.terraform.io/providers/hashicorp/azurerm/4.18.0/docs/data-sources/resource_group) | data source |
| [azurerm_subnet.existing_subnet](https://registry.terraform.io/providers/hashicorp/azurerm/4.18.0/docs/data-sources/subnet) | data source |
| [azurerm_subscription.current](https://registry.terraform.io/providers/hashicorp/azurerm/4.18.0/docs/data-sources/subscription) | data source |
| [azurerm_virtual_network.existing_vnet](https://registry.terraform.io/providers/hashicorp/azurerm/4.18.0/docs/data-sources/virtual_network) | data source |
| [azurerm_virtual_network.hub_vnet](https://registry.terraform.io/providers/hashicorp/azurerm/4.18.0/docs/data-sources/virtual_network) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allow_gateway_transit_from_hub"></a> [allow\_gateway\_transit\_from\_hub](#input\_allow\_gateway\_transit\_from\_hub) | Allow gateway transit from hub to spoke. Set to true if hub has a gateway and you want spoke to use it. | `bool` | `false` | no |
| <a name="input_existing_vnet_resource_group_name"></a> [existing\_vnet\_resource\_group\_name](#input\_existing\_vnet\_resource\_group\_name) | Resource group name of the existing VNet. Only used when vnet\_name is provided. Defaults to the Key Vault resource group if not specified. | `string` | `null` | no |
| <a name="input_hub_resource_group_name"></a> [hub\_resource\_group\_name](#input\_hub\_resource\_group\_name) | Resource group name of the hub virtual network. Required when private\_endpoint\_enabled is true and connecting to a hub. | `string` | `null` | no |
| <a name="input_hub_subscription_id"></a> [hub\_subscription\_id](#input\_hub\_subscription\_id) | Subscription ID of the hub network. Required when private\_endpoint\_enabled is true and connecting to a hub. | `string` | `null` | no |
| <a name="input_hub_vnet_name"></a> [hub\_vnet\_name](#input\_hub\_vnet\_name) | Name of the hub virtual network to peer with. Required when private\_endpoint\_enabled is true and connecting to a hub. | `string` | `null` | no |
| <a name="input_key_vault_name"></a> [key\_vault\_name](#input\_key\_vault\_name) | The name of the key vault. | `string` | n/a | yes |
| <a name="input_key_vault_resource_group_name"></a> [key\_vault\_resource\_group\_name](#input\_key\_vault\_resource\_group\_name) | The name of the resource group containing the key vault. | `string` | n/a | yes |
| <a name="input_location"></a> [location](#input\_location) | The location/region where the key vault is created. | `string` | n/a | yes |
| <a name="input_private_dns_zone_id"></a> [private\_dns\_zone\_id](#input\_private\_dns\_zone\_id) | Private DNS Zone ID for private endpoint. Use 'System' for Azure-managed zone, or provide custom zone ID. Only used when private\_endpoint\_enabled is true. | `string` | `"System"` | no |
| <a name="input_private_endpoint_enabled"></a> [private\_endpoint\_enabled](#input\_private\_endpoint\_enabled) | Enable private endpoint for Key Vault | `bool` | `false` | no |
| <a name="input_public_network_access_enabled"></a> [public\_network\_access\_enabled](#input\_public\_network\_access\_enabled) | n/a | `bool` | `false` | no |
| <a name="input_subnet_address_prefix"></a> [subnet\_address\_prefix](#input\_subnet\_address\_prefix) | Address prefix for the private endpoint subnet (only used if subnet\_name is not provided) | `string` | `"10.250.1.0/24"` | no |
| <a name="input_subnet_name"></a> [subnet\_name](#input\_subnet\_name) | Name of the subnet for private endpoint. If not provided, a new subnet will be created. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_use_remote_gateways"></a> [use\_remote\_gateways](#input\_use\_remote\_gateways) | Use remote gateways from hub VNet. Set to true only if hub has a VPN/ExpressRoute gateway configured. | `bool` | `false` | no |
| <a name="input_vnet_address_space"></a> [vnet\_address\_space](#input\_vnet\_address\_space) | Address space for the VNet (only used if vnet\_name is not provided) | `string` | `"10.250.0.0/16"` | no |
| <a name="input_vnet_name"></a> [vnet\_name](#input\_vnet\_name) | Name of the virtual network for private endpoint. If not provided, a new VNet will be created. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_key_vault_id"></a> [key\_vault\_id](#output\_key\_vault\_id) | The ID of the Azure Key Vault |
| <a name="output_key_vault_name"></a> [key\_vault\_name](#output\_key\_vault\_name) | The name of the Azure Key Vault |
| <a name="output_key_vault_resource_group"></a> [key\_vault\_resource\_group](#output\_key\_vault\_resource\_group) | Name of the resource group containing the Key Vault |
| <a name="output_key_vault_uri"></a> [key\_vault\_uri](#output\_key\_vault\_uri) | The URI of the Azure Key Vault |
| <a name="output_private_dns_zone_id"></a> [private\_dns\_zone\_id](#output\_private\_dns\_zone\_id) | ID of the private DNS zone (when System-managed) |
| <a name="output_private_endpoint_ip"></a> [private\_endpoint\_ip](#output\_private\_endpoint\_ip) | Private IP address of the Key Vault private endpoint |
| <a name="output_subnet_id"></a> [subnet\_id](#output\_subnet\_id) | ID of the subnet used for private endpoint |
| <a name="output_vnet_id"></a> [vnet\_id](#output\_vnet\_id) | ID of the virtual network used for private endpoint |
<!-- END_TF_DOCS -->

## Example Usage

### Public Key Vault
```hcl
module "key_vault_public" {
  source = "./buildingblock"

  key_vault_name                = "myapp-kv"
  key_vault_resource_group_name = "myapp-rg"
  location                      = "West Europe"
  public_network_access_enabled = true
  private_endpoint_enabled      = false
}
```

### Private Key Vault with Hub Peering
```hcl
module "key_vault_private" {
  source = "./buildingblock"

  key_vault_name                = "myapp-kv"
  key_vault_resource_group_name = "myapp-rg"
  location                      = "West Europe"
  public_network_access_enabled = false

  private_endpoint_enabled = true
  private_dns_zone_id      = "System"
  vnet_address_space       = "10.250.0.0/16"
  subnet_address_prefix    = "10.250.1.0/24"

  hub_subscription_id     = "00000000-0000-0000-0000-000000000000"
  hub_resource_group_name = "hub-network-rg"
  hub_vnet_name           = "hub-vnet"

  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}
```

## Security Best Practices

1. **Enable Private Endpoints**: Always use private endpoints for production workloads
2. **RBAC Authorization**: Use Azure RBAC for access control (enabled by default)
3. **Soft Delete and Purge Protection**: Enabled by default to prevent accidental deletion
4. **Network Isolation**: Disable public access for production environments
5. **Monitoring**: Enable diagnostic logging to Log Analytics
6. **Least Privilege**: Grant minimal required RBAC roles to users and applications

## Troubleshooting

### Private DNS Not Resolving
Ensure the Private DNS zone is linked to the VNet and DNS settings are configured correctly.

### Cannot Access from On-Premises
Verify VNet peering is established and DNS forwarding is configured for the private DNS zone.

### Permission Denied
Check Azure RBAC role assignments. Users need `Key Vault Secrets User` or similar roles.

## Related Resources

- [Azure Key Vault Documentation](https://docs.microsoft.com/en-us/azure/key-vault/)
- [Private Endpoints Overview](https://docs.microsoft.com/en-us/azure/private-link/private-endpoint-overview)
- [Azure RBAC for Key Vault](https://docs.microsoft.com/en-us/azure/key-vault/general/rbac-guide)
