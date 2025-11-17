output "project_name" {
  description = "Name of the created meshStack project"
  value       = meshstack_project.vm_project.metadata.name
}

output "tenant_uuid" {
  description = "UUID of the created Azure tenant"
  value       = meshstack_tenant_v4.vm_tenant.metadata.uuid
}

output "vm_building_block_uuid" {
  description = "UUID of the Azure VM building block"
  value       = meshstack_building_block_v2.azure_vm.metadata.uuid
}

output "summary" {
  description = "Summary with next steps and insights into created resources"
  value       = <<-EOT
# Azure Virtual Machine Starter Kit

✅ **Your environment is ready!**

This starter kit has set up the following resources in workspace `${var.workspace_identifier}`:

@project[${meshstack_project.vm_project.metadata.owned_by_workspace}.${meshstack_project.vm_project.metadata.name}]\
&nbsp;&nbsp;&nbsp;&nbsp;@tenant[${meshstack_tenant_v4.vm_tenant.metadata.uuid}]\
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;@buildingblock[${meshstack_building_block_v2.azure_vm.metadata.uuid}]

---

## What's Included

- **Azure Project**: A dedicated project for your virtual machine resources
- **Azure Tenant**: An Azure subscription tenant with your chosen landing zone
- **Virtual Machine**: ${var.vm_os_type} VM (${var.vm_size}) in ${var.vm_location}

---

## VM Details

- **VM Name**: ${local.identifier}
- **Operating System**: ${var.vm_os_type}
- **Size**: ${var.vm_size}
- **Region**: ${var.vm_location}
- **Public IP**: ${var.vm_enable_public_ip ? "Enabled" : "Disabled"}
- **Admin Username**: ${var.vm_admin_username}

---

## Next Steps

### 1. Access Your VM
${var.vm_os_type == "Linux" && var.vm_enable_public_ip ? "- Connect via SSH using your provided SSH key" : ""}
${var.vm_os_type == "Windows" && var.vm_enable_public_ip ? "- Connect via RDP using the admin credentials" : ""}
${!var.vm_enable_public_ip ? "- Connect through Azure Bastion or VPN (no public IP assigned)" : ""}

### 2. View Azure Resources
- [Access Azure Tenant](/#/w/${var.workspace_identifier}/p/${meshstack_project.vm_project.metadata.name}/i/${var.full_platform_identifier}/overview)

### 3. Manage Project Access
- Invite team members via meshStack:
  - [Project Access Management](/#/w/${var.workspace_identifier}/p/${meshstack_project.vm_project.metadata.name}/access-management/role-mapping/overview)

---

## Security Recommendations

1. **SSH Keys**: Rotate SSH keys regularly if using Linux
2. **Network Access**: Review NSG rules and restrict access as needed
3. **Updates**: Keep your VM updated with latest security patches
4. **Monitoring**: Enable Azure Monitor for VM performance and health tracking

---

🎉 Your Azure VM is ready to use!
EOT
}
