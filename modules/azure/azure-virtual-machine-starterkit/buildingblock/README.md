---
name: Azure Virtual Machine Starterkit
supportedPlatforms:
  - azure
description: |
  The Azure Virtual Machine Starterkit provides application teams with a pre-configured Azure environment. It includes a dedicated project, an Azure tenant, and a virtual machine for quick provisioning and testing.
---

# Azure Virtual Machine Starterkit Building Block

This documentation is intended as a reference documentation for cloud foundation or platform engineers using this module.

## Overview

The Azure VM Starterkit building block automates the creation of a complete Azure virtual machine environment including:

- **meshStack Project**: A dedicated project for organizing and managing the VM resources
- **Azure Tenant**: An Azure subscription tenant configured with the specified landing zone
- **Virtual Machine Building Block**: Automatically deploys an Azure VM with chosen specifications

## Features

- Single unified project (no dev/prod separation)
- Flexible VM configuration (Linux or Windows)
- Optional public IP assignment
- Automatic project admin assignment for the creator
- Customizable project tags

## Use Cases

- Quick VM provisioning for development or testing
- Sandbox environments for experimentation
- Training and learning environments
- Proof-of-concept workloads
- CI/CD build agents

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_meshstack"></a> [meshstack](#requirement\_meshstack) | 0.9.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [meshstack_building_block_v2.azure_vm](https://registry.terraform.io/providers/meshcloud/meshstack/0.9.0/docs/resources/building_block_v2) | resource |
| [meshstack_project.vm_project](https://registry.terraform.io/providers/meshcloud/meshstack/0.9.0/docs/resources/project) | resource |
| [meshstack_project_user_binding.creator_admin](https://registry.terraform.io/providers/meshcloud/meshstack/0.9.0/docs/resources/project_user_binding) | resource |
| [meshstack_tenant_v4.vm_tenant](https://registry.terraform.io/providers/meshcloud/meshstack/0.9.0/docs/resources/tenant_v4) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_azure_vm_definition_version_uuid"></a> [azure\_vm\_definition\_version\_uuid](#input\_azure\_vm\_definition\_version\_uuid) | UUID of the Azure Virtual Machine building block definition version. | `string` | n/a | yes |
| <a name="input_creator"></a> [creator](#input\_creator) | Information about the creator of the resources who will be assigned Project Admin role | <pre>object({<br>    type        = string<br>    identifier  = string<br>    displayName = string<br>    username    = optional(string)<br>    email       = optional(string)<br>    euid        = optional(string)<br>  })</pre> | n/a | yes |
| <a name="input_full_platform_identifier"></a> [full\_platform\_identifier](#input\_full\_platform\_identifier) | Full platform identifier of the Azure platform. | `string` | n/a | yes |
| <a name="input_landing_zone_identifier"></a> [landing\_zone\_identifier](#input\_landing\_zone\_identifier) | Azure Landing zone identifier for the tenant. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | This name will be used for the created project and VM | `string` | n/a | yes |
| <a name="input_project_tags_yaml"></a> [project\_tags\_yaml](#input\_project\_tags\_yaml) | YAML configuration for project tags. Expected structure:<pre>yaml<br>key1:<br>  - "value1"<br>  - "value2"<br>key2:<br>  - "value3"</pre> | `string` | `"{}"` | no |
| <a name="input_vm_admin_password"></a> [vm\_admin\_password](#input\_vm\_admin\_password) | The admin password for Windows VM (required for Windows). | `string` | `null` | no |
| <a name="input_vm_admin_username"></a> [vm\_admin\_username](#input\_vm\_admin\_username) | The admin username for the VM. | `string` | `"azureuser"` | no |
| <a name="input_vm_enable_public_ip"></a> [vm\_enable\_public\_ip](#input\_vm\_enable\_public\_ip) | Whether to create and assign a public IP address to the VM. | `bool` | `false` | no |
| <a name="input_vm_location"></a> [vm\_location](#input\_vm\_location) | The Azure region where the VM will be deployed. | `string` | `"westeurope"` | no |
| <a name="input_vm_os_type"></a> [vm\_os\_type](#input\_vm\_os\_type) | The operating system type (Linux or Windows). | `string` | `"Linux"` | no |
| <a name="input_vm_size"></a> [vm\_size](#input\_vm\_size) | The size of the virtual machine. | `string` | `"Standard_B1s"` | no |
| <a name="input_vm_ssh_public_key"></a> [vm\_ssh\_public\_key](#input\_vm\_ssh\_public\_key) | SSH public key for Linux VM authentication (required for Linux). | `string` | `null` | no |
| <a name="input_workspace_identifier"></a> [workspace\_identifier](#input\_workspace\_identifier) | The identifier of the meshStack workspace | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_project_name"></a> [project\_name](#output\_project\_name) | Name of the created meshStack project |
| <a name="output_summary"></a> [summary](#output\_summary) | Summary with next steps and insights into created resources |
| <a name="output_tenant_uuid"></a> [tenant\_uuid](#output\_tenant\_uuid) | UUID of the created Azure tenant |
| <a name="output_vm_building_block_uuid"></a> [vm\_building\_block\_uuid](#output\_vm\_building\_block\_uuid) | UUID of the Azure VM building block |
<!-- END_TF_DOCS -->

## Configuration Examples

### Basic Linux VM

```hcl
module "vm_starterkit" {
  source = "./modules/azure/azure-virtual-machine/starterkit/buildingblock"

  workspace_identifier           = "my-workspace"
  name                          = "my-dev-vm"
  full_platform_identifier      = "azure.my-platform"
  landing_zone_identifier       = "my-landing-zone"

  # Building block UUID (obtain from your meshStack setup)
  azure_vm_definition_version_uuid = "..."

  creator = {
    type        = "User"
    identifier  = "user123"
    displayName = "John Doe"
    username    = "jdoe"
  }

  vm_os_type         = "Linux"
  vm_size            = "Standard_B2s"
  vm_location        = "westeurope"
  vm_ssh_public_key  = file("~/.ssh/id_rsa.pub")
  vm_enable_public_ip = true
}
```

### Windows VM

```hcl
module "vm_starterkit" {
  source = "./modules/azure/azure-virtual-machine/starterkit/buildingblock"

  workspace_identifier     = "my-workspace"
  name                    = "my-win-vm"
  full_platform_identifier = "azure.my-platform"
  landing_zone_identifier  = "my-landing-zone"

  # Building block UUID
  azure_vm_definition_version_uuid = "..."

  creator = {
    type        = "User"
    identifier  = "user456"
    displayName = "Jane Smith"
    username    = "jsmith"
  }

  vm_os_type         = "Windows"
  vm_size            = "Standard_D2s_v3"
  vm_location        = "northeurope"
  vm_admin_password  = var.windows_admin_password
  vm_enable_public_ip = true
}
```

## Notes

- The resource group will be automatically created by the Azure VM building block
- Ensure SSH public key is provided for Linux VMs
- Ensure admin password is provided for Windows VMs
- Public IP is disabled by default for security
- Project tags can be customized using YAML format
