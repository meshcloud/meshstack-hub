# Azure Bastion

## Description
This building block provides an Azure Bastion Host for secure RDP and SSH connectivity to virtual machines in your Azure virtual network. It eliminates the need to expose VMs to the public internet while providing secure remote access through the Azure portal.

## Usage Motivation
This building block is for application teams that need secure, centralized access to virtual machines without exposing them to the public internet. Azure Bastion provides a secure and seamless RDP/SSH experience directly from the Azure portal, eliminating the need for VPN connections or jump boxes.

## Usage Examples
- A development team needs secure access to development VMs for debugging and maintenance without exposing them to the internet.
- An operations team requires secure administrative access to production VMs for monitoring and troubleshooting.
- A security team wants to provide controlled access to sensitive workloads while maintaining audit trails and compliance.

## Shared Responsibility

| Responsibility | Platform Team | Application Team |
|----------------|--------------|-----------------|
| Provisioning and configuring Azure Bastion | ✅ | ❌ |
| Managing Bastion subnet and network security | ✅ | ❌ |
| Maintaining Bastion availability and updates | ✅ | ❌ |
| Configuring VM access permissions | ❌ | ✅ |
| Managing VM user accounts and authentication | ❌ | ✅ |
| Monitoring and logging VM access sessions | ✅ | ⚠️ (Application-specific logs) |

## Recommendations for Secure and Efficient Bastion Usage
- **Use Azure RBAC**: Grant least-privilege access to VMs through proper role assignments
- **Enable session recording**: Configure diagnostic settings to log Bastion sessions for security audit
- **Monitor access patterns**: Use Azure Monitor to track unusual access patterns or failed connection attempts
- **Secure VM endpoints**: Ensure VMs have proper security configurations (firewalls, updated OS, etc.)
- **Use Just-In-Time access**: Consider combining with Azure Security Center's JIT VM access for additional security

## Network Requirements
- **Bastion Subnet**: Requires a dedicated subnet named "AzureBastionSubnet" with minimum /27 CIDR
- **Network Security Group**: Automatically configured with required rules for Bastion functionality
- **Public IP**: Standard SKU public IP required for Bastion connectivity
- **Virtual Network**: Must be deployed in an existing VNet with available address space