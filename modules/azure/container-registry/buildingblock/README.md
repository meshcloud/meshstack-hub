---
name: Azure Container Registry
supportedPlatforms:
  - azure
description: |
  Provides a production-grade Azure Container Registry for storing and managing Docker container images and OCI artifacts with private networking support.
category: container-registry
---

# Azure Container Registry Building Block

This Terraform module provisions an Azure Container Registry with optional private endpoint networking, VNet peering to hub networks, and AKS integration.

## Requirements
- Terraform >= 1.3.0
- Azure RM Provider ~> 4.36.0

## Architecture

The module supports multiple deployment scenarios:

1. **New VNet + Hub Peering** - Creates a new VNet and establishes peering to hub network
2. **Existing Shared VNet** - Uses an existing VNet (assumes already peered to hub)
3. **Private Isolated** - Private endpoint without hub connectivity
4. **Public ACR** - Internet-accessible registry

### Peering Logic

VNet peering to hub is **automatically determined**:
- **Created** when `vnet_name == null` (creating new VNet) AND `hub_vnet_name` is set
- **Skipped** when `vnet_name` is set (using existing VNet, assumes already connected to hub)

This automatic approach simplifies configuration by inferring intent from VNet creation vs. usage.

## Permissions

Please reference the [backplane implementation](../backplane/) for the required permissions to deploy this building block.

Key permissions include:
- `Microsoft.ContainerRegistry/*` - ACR management
- `Microsoft.Network/virtualNetworks/*` - VNet and subnet operations
- `Microsoft.Network/privateEndpoints/*` - Private endpoint creation
- `Microsoft.Network/privateDnsZones/*` - Private DNS zone integration
- `Microsoft.Network/privateDnsZones/join/action` - DNS zone association
- Hub subscription permissions for VNet peering (when applicable)

## Provider Configuration

This module requires two provider configurations when using hub peering:

```hcl
provider "azurerm" {
  alias           = "hub"
  subscription_id = "hub-subscription-id"
  features {}
}

module "acr" {
  source = "./buildingblock"

  providers = {
    azurerm     = azurerm
    azurerm.hub = azurerm.hub
  }

  # ... configuration
}
```

When not using hub peering, only the default provider is needed.

## Advanced Configuration

### Cross-Resource-Group VNet Support

The module supports using existing VNets from different resource groups:

```hcl
vnet_name                         = "shared-connectivity-vnet"
existing_vnet_resource_group_name = "connectivity-rg"
subnet_name                       = "acr-subnet"
```

If `existing_vnet_resource_group_name` is not specified, it defaults to the ACR's resource group.

### Private Endpoint Network Policies

The module configures subnets with `private_endpoint_network_policies = "NetworkSecurityGroupEnabled"` to allow NSG rules to secure private endpoint traffic.

### AKS Integration

When `aks_managed_identity_principal_id` is provided, the module automatically assigns the `AcrPull` role to the AKS managed identity.

## Resource Dependencies

When creating a new VNet:
- VNet must be created before private endpoint
- Subnet must be created before private endpoint
- Hub peering requires both VNets to exist

When using an existing VNet:
- VNet and subnet must already exist
- Data sources are used to reference existing resources

## Troubleshooting

### Private Endpoint DNS Resolution Issues

**Symptom:** ACR FQDN resolves to public IP instead of private IP

**Solutions:**
- Verify private DNS zone is linked to the VNet
- Check `private_dns_zone_id` is set to "System" or valid zone ID
- Confirm VNet peering allows DNS forwarding
- Test: `nslookup <acr-name>.azurecr.io` should return 10.x.x.x

### Hub Peering Not Created

**Symptom:** Expected hub peering but it wasn't created

**Cause:** Using existing VNet (`vnet_name` is set) - peering is automatically skipped

**Solution:** Either:
- Set `vnet_name = null` to create new VNet with peering
- Manually peer the existing VNet to hub outside this module

### AKS Cannot Pull Images

**Symptom:** `ImagePullBackOff` errors in AKS

**Solutions:**
- Verify `aks_managed_identity_principal_id` is correctly set
- Check AcrPull role assignment exists: `az role assignment list --assignee <managed-identity-id>`
- Confirm AKS and ACR are in same/peered VNets (for private ACR)
- Verify private DNS zone is linked to AKS VNet

### Permission Denied Errors During Deployment

**Symptom:** Terraform fails with authorization errors

**Solutions:**
- Verify backplane roles are assigned
- Check hub subscription provider is configured (for peering scenarios)
- Confirm `Microsoft.Network/privateDnsZones/join/action` permission exists

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 4.36.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.6.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_container_registry.acr](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_registry) | resource |
| [azurerm_private_dns_zone.acr_dns](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone) | resource |
| [azurerm_private_dns_zone_virtual_network_link.acr_dns_link](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone_virtual_network_link) | resource |
| [azurerm_private_endpoint.acr_pe](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint) | resource |
| [azurerm_resource_group.acr](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_role_assignment.acr_pull](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_subnet.pe_subnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_virtual_network.vnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) | resource |
| [azurerm_virtual_network_peering.acr_to_hub](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering) | resource |
| [azurerm_virtual_network_peering.hub_to_acr](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering) | resource |
| [random_string.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [azurerm_resource_group.hub_rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group) | data source |
| [azurerm_subnet.existing_subnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subnet) | data source |
| [azurerm_subscription.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subscription) | data source |
| [azurerm_virtual_network.existing_vnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/virtual_network) | data source |
| [azurerm_virtual_network.hub_vnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/virtual_network) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_acr_name"></a> [acr\_name](#input\_acr\_name) | Name of the Azure Container Registry (must be globally unique, alphanumeric only) | `string` | n/a | yes |
| <a name="input_admin_enabled"></a> [admin\_enabled](#input\_admin\_enabled) | Enable admin user for basic authentication (not recommended for production) | `bool` | `false` | no |
| <a name="input_aks_managed_identity_principal_id"></a> [aks\_managed\_identity\_principal\_id](#input\_aks\_managed\_identity\_principal\_id) | Principal ID of the AKS managed identity to grant AcrPull access. If provided, AcrPull role will be assigned automatically. | `string` | `null` | no |
| <a name="input_allow_gateway_transit_from_hub"></a> [allow\_gateway\_transit\_from\_hub](#input\_allow\_gateway\_transit\_from\_hub) | Allow gateway transit from hub to spoke. Set to true if hub has a gateway and you want spoke to use it. | `bool` | `false` | no |
| <a name="input_allowed_ip_ranges"></a> [allowed\_ip\_ranges](#input\_allowed\_ip\_ranges) | List of IP ranges (CIDR) allowed to access the ACR | `list(string)` | `[]` | no |
| <a name="input_anonymous_pull_enabled"></a> [anonymous\_pull\_enabled](#input\_anonymous\_pull\_enabled) | Enable anonymous pull access (allows unauthenticated pulls) | `bool` | `false` | no |
| <a name="input_data_endpoint_enabled"></a> [data\_endpoint\_enabled](#input\_data\_endpoint\_enabled) | Enable dedicated data endpoints (Premium SKU only) | `bool` | `false` | no |
| <a name="input_existing_vnet_resource_group_name"></a> [existing\_vnet\_resource\_group\_name](#input\_existing\_vnet\_resource\_group\_name) | Resource group name of the existing VNet. Only used when vnet\_name is provided. Defaults to the ACR resource group if not specified. | `string` | `null` | no |
| <a name="input_hub_resource_group_name"></a> [hub\_resource\_group\_name](#input\_hub\_resource\_group\_name) | Resource group name of the hub virtual network. Required when private\_endpoint\_enabled is true and connecting to a hub. | `string` | `null` | no |
| <a name="input_hub_subscription_id"></a> [hub\_subscription\_id](#input\_hub\_subscription\_id) | Subscription ID of the hub network. Required when private\_endpoint\_enabled is true and connecting to a hub. | `string` | `null` | no |
| <a name="input_hub_vnet_name"></a> [hub\_vnet\_name](#input\_hub\_vnet\_name) | Name of the hub virtual network to peer with. Required when private\_endpoint\_enabled is true and connecting to a hub. | `string` | `null` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region where resources will be deployed | `string` | `"Germany West Central"` | no |
| <a name="input_network_rule_bypass_option"></a> [network\_rule\_bypass\_option](#input\_network\_rule\_bypass\_option) | Whether to allow trusted Azure services to bypass network rules (AzureServices or None) | `string` | `"AzureServices"` | no |
| <a name="input_private_dns_zone_id"></a> [private\_dns\_zone\_id](#input\_private\_dns\_zone\_id) | Private DNS Zone ID for private endpoint. Use 'System' for Azure-managed zone, or provide custom zone ID. Only used when private\_endpoint\_enabled is true. | `string` | `"System"` | no |
| <a name="input_private_endpoint_enabled"></a> [private\_endpoint\_enabled](#input\_private\_endpoint\_enabled) | Enable private endpoint for ACR (Premium SKU required) | `bool` | `false` | no |
| <a name="input_public_network_access_enabled"></a> [public\_network\_access\_enabled](#input\_public\_network\_access\_enabled) | Enable public network access to the ACR | `bool` | `true` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Name of the resource group to create for the ACR | `string` | `"acr-rg"` | no |
| <a name="input_retention_days"></a> [retention\_days](#input\_retention\_days) | Number of days to retain untagged manifests (Premium SKU only, 0 to disable) | `number` | `7` | no |
| <a name="input_sku"></a> [sku](#input\_sku) | SKU tier for the ACR (Basic, Standard, Premium). Premium required for private endpoints and geo-replication. | `string` | `"Premium"` | no |
| <a name="input_subnet_address_prefix"></a> [subnet\_address\_prefix](#input\_subnet\_address\_prefix) | Address prefix for the private endpoint subnet (only used if subnet\_name is not provided) | `string` | `"10.250.1.0/24"` | no |
| <a name="input_subnet_name"></a> [subnet\_name](#input\_subnet\_name) | Name of the subnet for private endpoint. If not provided, a new subnet will be created. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_trust_policy_enabled"></a> [trust\_policy\_enabled](#input\_trust\_policy\_enabled) | Enable content trust policy (Premium SKU only) | `bool` | `false` | no |
| <a name="input_use_remote_gateways"></a> [use\_remote\_gateways](#input\_use\_remote\_gateways) | Use remote gateways from hub VNet. Set to true only if hub has a VPN/ExpressRoute gateway configured. | `bool` | `false` | no |
| <a name="input_vnet_address_space"></a> [vnet\_address\_space](#input\_vnet\_address\_space) | Address space for the VNet (only used if vnet\_name is not provided) | `string` | `"10.250.0.0/16"` | no |
| <a name="input_vnet_name"></a> [vnet\_name](#input\_vnet\_name) | Name of the virtual network for private endpoint. If not provided, a new VNet will be created. | `string` | `null` | no |
| <a name="input_zone_redundancy_enabled"></a> [zone\_redundancy\_enabled](#input\_zone\_redundancy\_enabled) | Enable zone redundancy for the ACR (Premium SKU only, available in select regions) | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_acr_id"></a> [acr\_id](#output\_acr\_id) | The ID of the Azure Container Registry |
| <a name="output_acr_login_server"></a> [acr\_login\_server](#output\_acr\_login\_server) | The login server URL for the Azure Container Registry |
| <a name="output_acr_name"></a> [acr\_name](#output\_acr\_name) | The name of the Azure Container Registry |
| <a name="output_admin_password"></a> [admin\_password](#output\_admin\_password) | Admin password for the Azure Container Registry (only available when admin\_enabled is true) |
| <a name="output_admin_username"></a> [admin\_username](#output\_admin\_username) | Admin username for the Azure Container Registry (only available when admin\_enabled is true) |
| <a name="output_private_dns_zone_id"></a> [private\_dns\_zone\_id](#output\_private\_dns\_zone\_id) | ID of the private DNS zone (when System-managed) |
| <a name="output_private_endpoint_ip"></a> [private\_endpoint\_ip](#output\_private\_endpoint\_ip) | Private IP address of the ACR private endpoint |
| <a name="output_resource_group_name"></a> [resource\_group\_name](#output\_resource\_group\_name) | Name of the resource group containing the ACR |
| <a name="output_subnet_id"></a> [subnet\_id](#output\_subnet\_id) | ID of the subnet used for private endpoint |
| <a name="output_vnet_id"></a> [vnet\_id](#output\_vnet\_id) | ID of the virtual network used for private endpoint |
<!-- END_TF_DOCS -->
