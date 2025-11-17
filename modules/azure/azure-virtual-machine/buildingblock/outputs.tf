output "vm_id" {
  value       = var.os_type == "Linux" ? azurerm_linux_virtual_machine.vm[0].id : azurerm_windows_virtual_machine.vm[0].id
  description = "The ID of the virtual machine"
}

output "vm_name" {
  value       = var.vm_name
  description = "The name of the virtual machine"
}

output "vm_private_ip" {
  value       = azurerm_network_interface.vm_nic.private_ip_address
  description = "The private IP address of the VM"
}

output "vm_public_ip" {
  value       = var.enable_public_ip ? azurerm_public_ip.vm_public_ip[0].ip_address : null
  description = "The public IP address of the VM (if enabled)"
}

output "resource_group_name" {
  value       = azurerm_resource_group.vm_rg.name
  description = "The name of the resource group"
}

output "network_interface_id" {
  value       = azurerm_network_interface.vm_nic.id
  description = "The ID of the network interface"
}

output "vnet_id" {
  value       = azurerm_virtual_network.vm_vnet.id
  description = "The ID of the virtual network"
}

output "vnet_name" {
  value       = azurerm_virtual_network.vm_vnet.name
  description = "The name of the virtual network"
}

output "subnet_id" {
  value       = azurerm_subnet.vm_subnet.id
  description = "The ID of the subnet"
}

output "vm_identity_principal_id" {
  value       = var.os_type == "Linux" ? azurerm_linux_virtual_machine.vm[0].identity[0].principal_id : azurerm_windows_virtual_machine.vm[0].identity[0].principal_id
  description = "The Principal ID of the system-assigned managed identity"
}

output "azure_portal_url" {
  value       = "https://portal.azure.com/#@${data.azurerm_client_config.current.tenant_id}/resource/subscriptions/${data.azurerm_subscription.current.subscription_id}/resourceGroups/${azurerm_resource_group.vm_rg.name}/providers/Microsoft.Compute/virtualMachines/${var.vm_name}/overview"
  description = "Direct link to the VM in Azure Portal"
}

output "summary" {
  description = "Markdown summary output of the building block with connection instructions"
  value       = <<EOT
# Azure Virtual Machine

Your Azure Virtual Machine was successfully created!

## VM Details

- **Name**: ${var.vm_name}
- **Resource Group**: ${azurerm_resource_group.vm_rg.name}
- **Location**: ${azurerm_resource_group.vm_rg.location}
- **Operating System**: ${var.os_type}
- **VM Size**: ${var.vm_size}
- **Private IP**: ${azurerm_network_interface.vm_nic.private_ip_address}${var.enable_public_ip ? "\n- **Public IP**: ${azurerm_public_ip.vm_public_ip[0].ip_address}" : ""}
- **Spot Instance**: ${var.enable_spot_instance ? "Yes (cost-optimized)" : "No"}

## Network Configuration

- **Virtual Network**: ${azurerm_virtual_network.vm_vnet.name}
- **VNet Address Space**: ${var.vnet_address_space}
- **Subnet**: ${azurerm_subnet.vm_subnet.name}
- **Subnet Prefix**: ${var.subnet_address_prefix}

## Storage Configuration

- **OS Disk Size**: ${var.os_disk_size_gb} GB
- **OS Disk Type**: ${var.os_disk_storage_type}${var.data_disk_size_gb > 0 ? "\n- **Data Disk Size**: ${var.data_disk_size_gb} GB\n- **Data Disk Type**: ${var.data_disk_storage_type}" : ""}

## Connection Instructions

### ${var.os_type == "Linux" ? "For Linux VM (SSH)" : "For Windows VM (RDP)"}

${var.os_type == "Linux" ? "Connect to your Linux VM using SSH:" : "Connect to your Windows VM using Remote Desktop Protocol (RDP):"}

${var.os_type == "Linux" ? "```bash\n# If using Azure Bastion or VPN (recommended):\nssh ${var.admin_username}@${azurerm_network_interface.vm_nic.private_ip_address}\n${var.enable_public_ip ? "\n# If public IP is enabled (less secure):\nssh ${var.admin_username}@${azurerm_public_ip.vm_public_ip[0].ip_address}\n" : ""}```" : "```powershell\n# If using Azure Bastion (recommended):\n# Use Azure Portal to connect via Bastion\n${var.enable_public_ip ? "\n# If public IP is enabled:\nmstsc /v:${azurerm_public_ip.vm_public_ip[0].ip_address}\n# Username: ${var.admin_username}\n" : ""}\n```"}

${!var.enable_public_ip ? "**Note**: This VM does not have a public IP. Use Azure Bastion, VPN, or a jump host to connect." : "**Security Warning**: This VM has a public IP. Consider using Azure Bastion for more secure access."}

${var.os_type == "Linux" ? "### SSH Key Authentication\n\nThis VM is configured with SSH key authentication. Ensure you have the private key corresponding to the public key used during provisioning." : "### Windows Authentication\n\nUse the admin username and password configured during provisioning."}

## Managed Identity

This VM has a system-assigned managed identity enabled:
- **Principal ID**: ${var.os_type == "Linux" ? azurerm_linux_virtual_machine.vm[0].identity[0].principal_id : azurerm_windows_virtual_machine.vm[0].identity[0].principal_id}

Use this identity to grant the VM access to other Azure resources without storing credentials.

${var.enable_spot_instance ? "## Spot Instance Notice\n\n⚠️ This VM is running as a spot instance to reduce costs. Be aware that:\n- The VM can be evicted when Azure needs capacity\n- This is suitable for dev/test and non-critical workloads\n- Consider implementing checkpointing or state persistence for long-running tasks\n" : ""}

## Next Steps

1. Connect to your VM using the instructions above
2. Install required software and configure your applications
3. Set up backup policies if needed
4. Configure monitoring and alerts
5. Review network security group rules for your use case

## Resources Created

- Resource Group: `${azurerm_resource_group.vm_rg.name}`
- Virtual Network: `${azurerm_virtual_network.vm_vnet.name}`
- Subnet: `${azurerm_subnet.vm_subnet.name}`
- Virtual Machine: `${var.vm_name}`
- Network Interface: `${var.vm_name}-nic`
- Network Security Group: `${var.vm_name}-nsg`${var.enable_public_ip ? "\n- Public IP: `${var.vm_name}-pip`" : ""}${var.data_disk_size_gb > 0 ? "\n- Data Disk: `${var.vm_name}-data-disk`" : ""}

EOT
}
