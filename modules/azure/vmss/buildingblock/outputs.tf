output "vmss_id" {
  value       = var.os_type == "Linux" ? azurerm_linux_virtual_machine_scale_set.vmss[0].id : azurerm_windows_virtual_machine_scale_set.vmss[0].id
  description = "The ID of the Virtual Machine Scale Set"
}

output "vmss_name" {
  value       = var.vmss_name
  description = "The name of the Virtual Machine Scale Set"
}

output "resource_group_name" {
  value       = azurerm_resource_group.vmss_rg.name
  description = "The name of the resource group"
}

output "location" {
  value       = azurerm_resource_group.vmss_rg.location
  description = "The Azure region where resources are deployed"
}

output "vnet_id" {
  value       = data.azurerm_virtual_network.spoke_vnet.id
  description = "The ID of the virtual network"
}

output "vnet_name" {
  value       = data.azurerm_virtual_network.spoke_vnet.name
  description = "The name of the virtual network"
}

output "subnet_id" {
  value       = data.azurerm_subnet.vmss_subnet.id
  description = "The ID of the subnet"
}

output "load_balancer_id" {
  value       = var.enable_load_balancer ? azurerm_lb.vmss_lb[0].id : null
  description = "The ID of the load balancer (if enabled)"
}

output "load_balancer_frontend_ip" {
  value       = var.enable_load_balancer ? (var.enable_public_ip ? azurerm_public_ip.lb_public_ip[0].ip_address : azurerm_lb.vmss_lb[0].frontend_ip_configuration[0].private_ip_address) : null
  description = "The frontend IP address of the load balancer (public or private)"
}

output "public_ip_address" {
  value       = var.enable_load_balancer && var.enable_public_ip ? azurerm_public_ip.lb_public_ip[0].ip_address : "no public IP assigned"
  description = "The public IP address of the load balancer (if enabled)"
}

output "vmss_identity_principal_id" {
  value       = var.os_type == "Linux" ? azurerm_linux_virtual_machine_scale_set.vmss[0].identity[0].principal_id : azurerm_windows_virtual_machine_scale_set.vmss[0].identity[0].principal_id
  description = "The Principal ID of the system-assigned managed identity"
}

output "autoscaling_enabled" {
  value       = var.enable_autoscaling
  description = "Whether autoscaling is enabled"
}

output "current_instances" {
  value       = var.instances
  description = "The configured number of instances"
}

output "instance_size" {
  value       = var.sku
  description = "The SKU/size of VM instances"
}

output "summary" {
  description = "Markdown summary output of the building block"
  value       = <<EOT
- *Name*: ${var.vmss_name}
- *Resource Group*: ${azurerm_resource_group.vmss_rg.name}
- *Location*: ${azurerm_resource_group.vmss_rg.location}
- *Operating System*: ${var.os_type}
- *Instance Size*: ${var.sku}
- *Initial Instances*: ${var.instances}
- *Upgrade Mode*: ${var.upgrade_mode}
- *Spot Instances*: ${var.enable_spot_instances ? "Yes (cost-optimized)" : "No"}

${var.enable_autoscaling ? "Autoscaling is enabled ✅\n\n- *Min Instances*: ${var.min_instances}\n- *Max Instances*: ${var.max_instances}\n- *Scale Out Threshold*: ${var.scale_out_cpu_threshold}% CPU\n- *Scale In Threshold*: ${var.scale_in_cpu_threshold}% CPU\n\nThe scale set will automatically adjust the number of instances based on CPU utilization." : "Autoscaling is disabled. To scale manually:\n\n```bash\naz vmss scale --resource-group ${azurerm_resource_group.vmss_rg.name} --name ${var.vmss_name} --new-capacity <number>\n```"}

${var.enable_load_balancer ? "The load balancer is enabled ✅\n\n- *SKU*: ${var.load_balancer_sku}\n- *Frontend IP*: ${var.enable_public_ip ? azurerm_public_ip.lb_public_ip[0].ip_address : azurerm_lb.vmss_lb[0].frontend_ip_configuration[0].private_ip_address} ${var.enable_public_ip ? "(Public)" : "(Private)"}\n- *Frontend Port*: ${var.frontend_port}\n- *Backend Port*: ${var.backend_port}\n- *Health Probe*: ${var.health_probe_protocol}:${var.health_probe_port}${var.health_probe_protocol != "Tcp" ? var.health_probe_request_path : ""}\n\nTraffic is distributed across all healthy instances." : "No load balancer configured. Consider enabling for production workloads."}

- *Virtual Network*: ${data.azurerm_virtual_network.spoke_vnet.name}
- *VNet Address Space*: ${join(", ", data.azurerm_virtual_network.spoke_vnet.address_space)}
- *Subnet*: ${data.azurerm_subnet.vmss_subnet.name}
- *Subnet Prefix*: ${join(", ", data.azurerm_subnet.vmss_subnet.address_prefixes)}
- *Network Security Group*: ${azurerm_network_security_group.vmss_nsg.name}

Security rules:

${var.os_type == "Linux" && var.enable_ssh_access ? "- ✅ SSH (port 22) - ENABLED" : ""}${var.os_type == "Linux" && !var.enable_ssh_access ? "- ❌ SSH (port 22) - DISABLED (use Azure Bastion for secure access)" : ""}
${var.os_type == "Windows" && var.enable_rdp_access ? "- ✅ RDP (port 3389) - ENABLED" : ""}${var.os_type == "Windows" && !var.enable_rdp_access ? "- ❌ RDP (port 3389) - DISABLED (use Azure Bastion for secure access)" : ""}
${var.enable_load_balancer ? "- ✅ Application Port (${var.backend_port}) - ENABLED" : ""}

${length(var.zones) > 0 ? "Availability zones are used ✅\n\n- *Zones*: ${join(", ", var.zones)}\n- *Zone Balancing*: Enabled\n\nInstances are distributed across multiple availability zones for maximum resiliency." : "The scale set runs in a single zone. Consider using availability zones for production workloads to achieve 99.99% SLA."}

- *OS Disk Size*: ${var.os_disk_size_gb} GB
- *OS Disk Type*: ${var.os_disk_storage_type}
- *Boot Diagnostics*: ${var.enable_boot_diagnostics ? "Enabled" : "Disabled"}

This scale set has a system-assigned managed identity enabled:
- *Principal ID*: ${var.os_type == "Linux" ? azurerm_linux_virtual_machine_scale_set.vmss[0].identity[0].principal_id : azurerm_windows_virtual_machine_scale_set.vmss[0].identity[0].principal_id}

Use this identity to grant VM instances access to other Azure resources without storing credentials.

${var.enable_spot_instances ? "# Spot Instances Notice ⚠️\n\nThis scale set uses spot instances to reduce costs:\n- VMs can be evicted when Azure needs capacity\n- Suitable for fault-tolerant, stateless workloads\n- Not recommended for production databases or stateful applications\n- Eviction policy: ${var.spot_eviction_policy}\n" : ""}

# Connection & Management

View the scale set status:

```bash
az vmss list-instances \
  --resource-group ${azurerm_resource_group.vmss_rg.name} \
  --name ${var.vmss_name} \
  --output table
```

Scale manually:

```bash
az vmss scale \
  --resource-group ${azurerm_resource_group.vmss_rg.name} \
  --name ${var.vmss_name} \
  --new-capacity <number>
```

Update the instances after image changes:

```bash
az vmss update-instances \
  --resource-group ${azurerm_resource_group.vmss_rg.name} \
  --name ${var.vmss_name} \
  --instance-ids "*"
```

${var.os_type == "Linux" && var.enable_ssh_access ? "SSH to a specific instance:\n\n```bash\n# List instances\naz vmss list-instance-connection-info \\\n  --resource-group ${azurerm_resource_group.vmss_rg.name} \\\n  --name ${var.vmss_name}\n\n# Connect to instance\nssh ${var.admin_username}@<instance-ip>\n```" : ""}

${!var.enable_ssh_access && !var.enable_rdp_access ? "Direct SSH/RDP access is disabled. Use Azure Bastion or configure a jump host for secure access to instances." : ""}

# Resources Created

- Resource Group: \`${azurerm_resource_group.vmss_rg.name}\`
- VM Scale Set: \`${var.vmss_name}\`
- Network Security Group: \`${azurerm_network_security_group.vmss_nsg.name}\`${var.enable_load_balancer ? "\n- Load Balancer: `${var.vmss_name}-lb`" : ""}${var.enable_load_balancer && var.enable_public_ip ? "\n- Public IP: `${var.vmss_name}-lb-pip`" : ""}${var.enable_autoscaling ? "\n- Autoscale Settings: `${var.vmss_name}-autoscale`" : ""}

*Note*: Uses existing spoke VNet \`${data.azurerm_virtual_network.spoke_vnet.name}\` and subnet \`${data.azurerm_subnet.vmss_subnet.name}\`

# Performance Optimization Tips

${var.upgrade_mode == "Manual" ? "- Consider using *Rolling* or *Automatic* upgrade mode for easier updates" : ""}
${!var.enable_autoscaling ? "- Enable *autoscaling* to automatically handle traffic spikes" : ""}
${length(var.zones) == 0 ? "- Use *availability zones* for better redundancy and 99.99% SLA" : ""}
${var.os_disk_storage_type == "Standard_LRS" ? "- Upgrade to *Premium_LRS* or *StandardSSD_LRS* for better IOPS" : ""}
${var.enable_load_balancer && var.load_balancer_sku == "Basic" ? "- Upgrade to *Standard* load balancer SKU for production workloads" : ""}

EOT
}
