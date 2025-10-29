---
name: Azure Virtual Machine
supportedPlatforms:
  - azure
description: |
  (ALPHA) Provisions an Azure Virtual Machine (VM) with support for both Linux and Windows operating systems, including network interface, optional public IP, network security group, and optional data disk.
---

# Azure Virtual Machine

This Terraform module provisions an Azure Virtual Machine along with necessary networking components and optional data disks.

## Features

- Support for both Linux and Windows VMs
- Automatic virtual network and subnet creation
- Configurable network address spaces
- Configurable VM size and disk types
- Optional public IP address
- Network Security Group (NSG) for network isolation
- System-assigned managed identity
- Optional data disk attachment
- Customizable OS images

## Requirements
- Terraform `>= 1.0`
- AzureRM Provider `>= 4.18.0`

## Providers

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.18.0"
    }
  }
}

provider "azurerm" {
  features {}
}
```

## Usage Examples

### Linux VM with SSH Key

```hcl
module "linux_vm" {
  source = "./buildingblock"

  vm_name             = "my-linux-vm"
  resource_group_name = "my-rg"
  location            = "West Europe"
  os_type             = "Linux"
  vm_size             = "Standard_B2s"
  admin_username      = "azureuser"
  ssh_public_key      = file("~/.ssh/id_rsa.pub")
  enable_public_ip    = false

  # Optional: customize network settings
  # vnet_address_space    = "10.0.0.0/16"
  # subnet_address_prefix = "10.0.1.0/24"

  tags = {
    Environment = "Development"
    Project     = "MyProject"
  }
}
```

### Windows VM with Password

```hcl
module "windows_vm" {
  source = "./buildingblock"

  vm_name             = "my-windows-vm"
  resource_group_name = "my-rg"
  location            = "West Europe"
  os_type             = "Windows"
  vm_size             = "Standard_D2s_v3"
  admin_username      = "adminuser"
  admin_password      = "P@ssw0rd123!"
  enable_public_ip    = true

  image_publisher     = "MicrosoftWindowsServer"
  image_offer         = "WindowsServer"
  image_sku           = "2022-datacenter-azure-edition"
  image_version       = "latest"

  tags = {
    Environment = "Production"
    Project     = "MyProject"
  }
}
```

### VM with Data Disk

```hcl
module "vm_with_data_disk" {
  source = "./buildingblock"

  vm_name                = "my-vm-with-disk"
  resource_group_name    = "my-rg"
  location               = "West Europe"
  os_type                = "Linux"
  admin_username         = "azureuser"
  ssh_public_key         = file("~/.ssh/id_rsa.pub")

  data_disk_size_gb      = 256
  data_disk_storage_type = "Premium_LRS"
}
```

### Spot Instance for Maximum Cost Savings

```hcl
module "spot_vm" {
  source = "./buildingblock"

  vm_name                = "my-spot-vm"
  resource_group_name    = "my-rg"
  location               = "West Europe"
  os_type                = "Linux"
  admin_username         = "azureuser"
  ssh_public_key         = file("~/.ssh/id_rsa.pub")

  enable_spot_instance   = true
  spot_eviction_policy   = "Deallocate"
  spot_max_bid_price     = -1  # Pay up to on-demand price
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_azuread"></a> [azuread](#requirement\_azuread) | ~>3.6.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~>4.50.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~>3.7.2 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_linux_virtual_machine.vm](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine) | resource |
| [azurerm_managed_disk.data_disk](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/managed_disk) | resource |
| [azurerm_network_interface.vm_nic](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface) | resource |
| [azurerm_network_interface_security_group_association.vm_nsg_association](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface_security_group_association) | resource |
| [azurerm_network_security_group.vm_nsg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) | resource |
| [azurerm_network_security_rule.allow_rdp](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_rule) | resource |
| [azurerm_network_security_rule.allow_ssh](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_rule) | resource |
| [azurerm_public_ip.vm_public_ip](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) | resource |
| [azurerm_resource_group.vm_rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_subnet.vm_subnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_virtual_machine_data_disk_attachment.linux_data_disk_attachment](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine_data_disk_attachment) | resource |
| [azurerm_virtual_machine_data_disk_attachment.windows_data_disk_attachment](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine_data_disk_attachment) | resource |
| [azurerm_virtual_network.vm_vnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) | resource |
| [azurerm_windows_virtual_machine.vm](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/windows_virtual_machine) | resource |
| [random_string.resource_code](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |
| [azurerm_subscription.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subscription) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_admin_password"></a> [admin\_password](#input\_admin\_password) | The admin password for Windows VM (required for Windows) | `string` | `null` | no |
| <a name="input_admin_username"></a> [admin\_username](#input\_admin\_username) | The admin username for the VM | `string` | `"azureuser"` | no |
| <a name="input_data_disk_size_gb"></a> [data\_disk\_size\_gb](#input\_data\_disk\_size\_gb) | The size of the data disk in GB. Set to 0 to skip data disk creation | `number` | `0` | no |
| <a name="input_data_disk_storage_type"></a> [data\_disk\_storage\_type](#input\_data\_disk\_storage\_type) | The storage account type for the data disk | `string` | `"Standard_LRS"` | no |
| <a name="input_enable_public_ip"></a> [enable\_public\_ip](#input\_enable\_public\_ip) | Whether to create and assign a public IP address to the VM | `bool` | `false` | no |
| <a name="input_enable_spot_instance"></a> [enable\_spot\_instance](#input\_enable\_spot\_instance) | Enable spot instance for significant cost savings (VM can be evicted when Azure needs capacity) | `bool` | `false` | no |
| <a name="input_image_offer"></a> [image\_offer](#input\_image\_offer) | The offer of the image | `string` | `"0001-com-ubuntu-server-jammy"` | no |
| <a name="input_image_publisher"></a> [image\_publisher](#input\_image\_publisher) | The publisher of the image | `string` | `"Canonical"` | no |
| <a name="input_image_sku"></a> [image\_sku](#input\_image\_sku) | The SKU of the image | `string` | `"22_04-lts-gen2"` | no |
| <a name="input_image_version"></a> [image\_version](#input\_image\_version) | The version of the image | `string` | `"latest"` | no |
| <a name="input_location"></a> [location](#input\_location) | The Azure region where resources will be deployed | `string` | n/a | yes |
| <a name="input_os_disk_size_gb"></a> [os\_disk\_size\_gb](#input\_os\_disk\_size\_gb) | The size of the OS disk in GB | `number` | `30` | no |
| <a name="input_os_disk_storage_type"></a> [os\_disk\_storage\_type](#input\_os\_disk\_storage\_type) | The storage account type for the OS disk | `string` | `"Standard_LRS"` | no |
| <a name="input_os_type"></a> [os\_type](#input\_os\_type) | The operating system type (Linux or Windows) | `string` | `"Linux"` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | The name of the resource group | `string` | n/a | yes |
| <a name="input_spot_eviction_policy"></a> [spot\_eviction\_policy](#input\_spot\_eviction\_policy) | Eviction policy for spot instances (Deallocate or Delete) | `string` | `"Deallocate"` | no |
| <a name="input_spot_max_bid_price"></a> [spot\_max\_bid\_price](#input\_spot\_max\_bid\_price) | Maximum price to pay for spot instance per hour. -1 means pay up to on-demand price. Default is -1 for maximum availability | `number` | `-1` | no |
| <a name="input_ssh_public_key"></a> [ssh\_public\_key](#input\_ssh\_public\_key) | SSH public key for Linux VM authentication (required for Linux) | `string` | `null` | no |
| <a name="input_subnet_address_prefix"></a> [subnet\_address\_prefix](#input\_subnet\_address\_prefix) | The address prefix for the subnet | `string` | `"10.0.1.0/24"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_vm_name"></a> [vm\_name](#input\_vm\_name) | The name of the virtual machine | `string` | n/a | yes |
| <a name="input_vm_size"></a> [vm\_size](#input\_vm\_size) | The size of the virtual machine | `string` | `"Standard_B1s"` | no |
| <a name="input_vnet_address_space"></a> [vnet\_address\_space](#input\_vnet\_address\_space) | The address space for the virtual network | `string` | `"10.0.0.0/16"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_network_interface_id"></a> [network\_interface\_id](#output\_network\_interface\_id) | The ID of the network interface |
| <a name="output_resource_group_name"></a> [resource\_group\_name](#output\_resource\_group\_name) | The name of the resource group |
| <a name="output_subnet_id"></a> [subnet\_id](#output\_subnet\_id) | The ID of the subnet |
| <a name="output_summary"></a> [summary](#output\_summary) | Markdown summary output of the building block with connection instructions |
| <a name="output_vm_id"></a> [vm\_id](#output\_vm\_id) | The ID of the virtual machine |
| <a name="output_vm_identity_principal_id"></a> [vm\_identity\_principal\_id](#output\_vm\_identity\_principal\_id) | The Principal ID of the system-assigned managed identity |
| <a name="output_vm_name"></a> [vm\_name](#output\_vm\_name) | The name of the virtual machine |
| <a name="output_vm_private_ip"></a> [vm\_private\_ip](#output\_vm\_private\_ip) | The private IP address of the VM |
| <a name="output_vm_public_ip"></a> [vm\_public\_ip](#output\_vm\_public\_ip) | The public IP address of the VM (if enabled) |
| <a name="output_vnet_id"></a> [vnet\_id](#output\_vnet\_id) | The ID of the virtual network |
| <a name="output_vnet_name"></a> [vnet\_name](#output\_vnet\_name) | The name of the virtual network |
<!-- END_TF_DOCS -->

## Common VM Sizes

| Size | vCPUs | RAM (GB) | Use Case |
|------|-------|----------|----------|
| Standard_B1s | 1 | 1 | Very small workloads |
| Standard_B2s | 2 | 4 | Development/testing |
| Standard_D2s_v3 | 2 | 8 | General purpose |
| Standard_D4s_v3 | 4 | 16 | General purpose |
| Standard_E4s_v3 | 4 | 32 | Memory-intensive |

## Spot Instances

Azure Spot VMs offer significant cost savings (up to 90% off on-demand prices) by using Azure's excess capacity. However, they can be evicted when Azure needs the capacity back.

**When to use Spot Instances:**
- Development and testing environments
- Batch processing jobs
- Non-critical workloads that can tolerate interruptions
- Stateless applications with external data storage

**When NOT to use Spot Instances:**
- Production workloads requiring high availability
- Database servers with local data
- Critical applications that cannot tolerate downtime

## Security Considerations

- VMs are deployed with system-assigned managed identities for secure Azure resource access
- Network Security Groups are automatically created for network isolation
- Linux VMs use SSH key authentication (password authentication disabled)
- Windows VMs require secure password configuration
- Consider using Azure Bastion or VPN for secure remote access instead of public IPs
