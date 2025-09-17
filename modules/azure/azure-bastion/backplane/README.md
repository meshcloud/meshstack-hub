# Azure Bastion Building Block

This documentation is intended as a reference documentation for platform engineers using this module.

## Permissions

This building block requires permissions to deploy Azure Bastion resources including:
- Bastion Host creation and management
- Public IP address provisioning
- Virtual network subnet creation and modification
- Network Security Group management
- Resource locking capabilities

The backplane establishes the necessary role definitions and assignments for secure deployment.

## Architecture

The building block creates:
- **Azure Bastion Host**: Provides secure RDP/SSH connectivity
- **AzureBastionSubnet**: Dedicated subnet with minimum /27 CIDR requirement
- **Public IP Address**: Standard SKU for Bastion connectivity
- **Network Security Group**: Pre-configured with all required Bastion rules
- **Resource Locks**: Optional protection against accidental deletion/modification

## Security Implementation

### Network Security Group Rules
**Inbound:**
- HTTPS (443) from Internet for user connections
- HTTPS (443) from GatewayManager for Azure control plane
- HTTPS (443) from AzureLoadBalancer for health probes
- Ports 8080, 5701 from VirtualNetwork for inter-Bastion communication

**Outbound:**
- SSH (22) and RDP (3389) to VirtualNetwork for VM connections
- HTTPS (443) to AzureCloud for Azure services
- Ports 8080, 5701 to VirtualNetwork for Bastion communication
- HTTP (80) to Internet for session metadata

### Resource Protection
- Management locks prevent accidental deletion of Bastion host
- Subnet locks prevent modification of critical network configuration
- RBAC integration ensures proper access control

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_role_assignment.buildingblock_deploy](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_definition.buildingblock_deploy](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_definition) | resource |
| [azurerm_subscription.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subscription) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_name"></a> [name](#input\_name) | Name of the building block | `string` | n/a | yes |
| <a name="input_principal_ids"></a> [principal\_ids](#input\_principal\_ids) | Principal IDs to assign the role to | `set(string)` | n/a | yes |
| <a name="input_scope"></a> [scope](#input\_scope) | Scope for the role assignment | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_role_definition_id"></a> [role\_definition\_id](#output\_role\_definition\_id) | The ID of the created role definition |
<!-- END_TF_DOCS -->