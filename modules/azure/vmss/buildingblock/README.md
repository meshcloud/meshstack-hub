---
name: Azure Virtual Machine Scale Set
supportedPlatforms:
  - azure
description: Provides Azure Virtual Machine Scale Sets for horizontally scalable compute workloads with autoscaling, load balancing, and high availability across availability zones.
category: compute
---

# Azure Virtual Machine Scale Set Building Block

This building block deploys Azure Virtual Machine Scale Sets (VMSS) to provide horizontally scalable compute resources with built-in autoscaling, load balancing, and high availability capabilities.

## Features

- **Multi-OS Support**: Deploy Linux or Windows VMSS with pre-configured images
- **Autoscaling**: CPU-based autoscaling with configurable thresholds and instance limits
- **Load Balancing**: Optional Standard Load Balancer with health probes and custom rules
- **High Availability**: Multi-zone deployment support for increased resilience
- **Cost Optimization**: Spot instance support for non-critical workloads
- **Flexible Upgrades**: Support for Manual, Automatic, and Rolling upgrade modes
- **Network Integration**: Creates dedicated VNet and subnet or uses existing network
- **Managed Identity**: System-assigned identity for Azure service authentication
- **Custom Initialization**: Cloud-init/custom-data support for VM bootstrapping

## Architecture

The building block creates:

**Compute Infrastructure:**
- Linux or Windows Virtual Machine Scale Set
- Configurable VM SKU and instance counts
- System-assigned managed identity
- Optional spot instances for cost savings

**Networking:**
- Virtual Network (if not existing)
- Dedicated subnet for VMSS instances
- Optional Standard Load Balancer with public or private frontend
- Backend address pool for VMSS instances
- Health probes for instance monitoring

**Autoscaling:**
- Monitor-based autoscaling rules
- CPU threshold-based scale out/in
- Configurable min/max/default capacity

## Usage

### Basic Linux VMSS

```hcl
module "linux_vmss" {
  source = "./azure-vmss/buildingblock"

  vmss_name           = "app-vmss"
  resource_group_name = "rg-production"
  location            = "West Europe"
  sku                 = "Standard_D2s_v3"
  instances           = 3

  os_type         = "Linux"
  admin_username  = "azureuser"
  ssh_public_key  = var.ssh_public_key

  vnet_address_space    = "10.1.0.0/16"
  subnet_address_prefix = "10.1.1.0/24"

  tags = {
    Environment = "Production"
    Application = "WebApp"
  }
}
```

### VMSS with Autoscaling and Load Balancer

```hcl
module "scalable_web_app" {
  source = "./azure-vmss/buildingblock"

  vmss_name           = "web-vmss"
  resource_group_name = "rg-web-app"
  location            = "West Europe"
  sku                 = "Standard_D2s_v3"

  os_type         = "Linux"
  admin_username  = "webadmin"
  ssh_public_key  = var.ssh_public_key

  vnet_address_space    = "10.2.0.0/16"
  subnet_address_prefix = "10.2.1.0/24"

  enable_autoscaling        = true
  autoscale_min             = 2
  autoscale_max             = 10
  autoscale_default         = 3
  cpu_scale_out_threshold   = 75
  cpu_scale_in_threshold    = 25

  enable_load_balancer   = true
  enable_public_ip       = true
  health_probe_protocol  = "Http"
  health_probe_port      = 80
  health_probe_path      = "/health"

  lb_rules = [
    {
      name          = "http"
      protocol      = "Tcp"
      frontend_port = 80
      backend_port  = 80
    },
    {
      name          = "https"
      protocol      = "Tcp"
      frontend_port = 443
      backend_port  = 443
    }
  ]

  custom_data = base64encode(<<-EOT
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
    systemctl start nginx
    systemctl enable nginx
  EOT
  )

  tags = {
    Environment = "Production"
    Application = "WebApp"
  }
}
```

### Windows VMSS with Spot Instances

```hcl
module "windows_batch_processing" {
  source = "./azure-vmss/buildingblock"

  vmss_name           = "batch-vmss"
  resource_group_name = "rg-batch"
  location            = "West Europe"
  sku                 = "Standard_D4s_v3"

  os_type        = "Windows"
  admin_username = "winadmin"
  admin_password = var.admin_password

  vnet_address_space    = "10.3.0.0/16"
  subnet_address_prefix = "10.3.1.0/24"

  enable_spot_instances  = true
  spot_max_bid_price     = -1
  spot_eviction_policy   = "Deallocate"

  enable_autoscaling    = true
  autoscale_min         = 0
  autoscale_max         = 20
  autoscale_default     = 2

  image_publisher = "MicrosoftWindowsServer"
  image_offer     = "WindowsServer"
  image_sku       = "2022-Datacenter"
  image_version   = "latest"

  tags = {
    Environment = "Production"
    Workload    = "BatchProcessing"
  }
}
```

### Multi-Zone VMSS with Rolling Upgrades

```hcl
module "highly_available_app" {
  source = "./azure-vmss/buildingblock"

  vmss_name           = "ha-app-vmss"
  resource_group_name = "rg-ha-app"
  location            = "West Europe"
  sku                 = "Standard_D2s_v3"

  os_type         = "Linux"
  admin_username  = "appuser"
  ssh_public_key  = var.ssh_public_key

  vnet_address_space    = "10.4.0.0/16"
  subnet_address_prefix = "10.4.1.0/24"

  zones        = ["1", "2", "3"]
  upgrade_mode = "Rolling"

  enable_autoscaling = true
  autoscale_min      = 3
  autoscale_max      = 15
  autoscale_default  = 6

  enable_load_balancer = true
  enable_public_ip     = true

  lb_rules = [
    {
      name          = "app"
      protocol      = "Tcp"
      frontend_port = 8080
      backend_port  = 8080
    }
  ]

  tags = {
    Environment     = "Production"
    HighAvailability = "true"
  }
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| vmss_name | Name of the Virtual Machine Scale Set | string | - | yes |
| resource_group_name | Name of the resource group | string | - | yes |
| location | Azure region for deployment | string | - | yes |
| sku | VM SKU (e.g., Standard_D2s_v3) | string | - | yes |
| instances | Number of VM instances (ignored if autoscaling enabled) | number | 2 | no |
| os_type | Operating system type (Linux or Windows) | string | "Linux" | no |
| admin_username | Administrator username | string | "azureuser" | no |
| admin_password | Administrator password (required for Windows) | string | null | no |
| ssh_public_key | SSH public key (required for Linux) | string | null | no |
| vnet_address_space | Address space for the virtual network | string | "10.0.0.0/16" | no |
| subnet_address_prefix | Address prefix for the subnet | string | "10.0.1.0/24" | no |
| enable_autoscaling | Enable autoscaling | bool | false | no |
| autoscale_min | Minimum number of instances | number | 1 | no |
| autoscale_max | Maximum number of instances | number | 10 | no |
| autoscale_default | Default number of instances | number | 2 | no |
| cpu_scale_out_threshold | CPU percentage to trigger scale out | number | 75 | no |
| cpu_scale_in_threshold | CPU percentage to trigger scale in | number | 25 | no |
| enable_load_balancer | Enable Standard Load Balancer | bool | false | no |
| enable_public_ip | Enable public IP for load balancer | bool | true | no |
| lb_rules | Load balancer rules | list(object) | [] | no |
| health_probe_protocol | Health probe protocol (Tcp or Http) | string | "Tcp" | no |
| health_probe_port | Health probe port | number | 80 | no |
| health_probe_path | Health probe path (for Http) | string | "/" | no |
| upgrade_mode | Upgrade mode (Manual, Automatic, Rolling) | string | "Manual" | no |
| zones | Availability zones | list(string) | [] | no |
| enable_spot_instances | Enable spot instances | bool | false | no |
| spot_max_bid_price | Maximum bid price (-1 for pay-as-you-go) | number | -1 | no |
| spot_eviction_policy | Spot eviction policy (Deallocate or Delete) | string | "Deallocate" | no |
| custom_data | Custom data for VM initialization | string | null | no |
| image_publisher | OS image publisher | string | "Canonical" | no |
| image_offer | OS image offer | string | "0001-com-ubuntu-server-jammy" | no |
| image_sku | OS image SKU | string | "22_04-lts-gen2" | no |
| image_version | OS image version | string | "latest" | no |
| os_disk_storage_type | OS disk storage type | string | "Premium_LRS" | no |
| os_disk_size_gb | OS disk size in GB | number | null | no |
| tags | Resource tags | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| vmss_id | The ID of the Virtual Machine Scale Set |
| vmss_name | The name of the Virtual Machine Scale Set |
| vmss_principal_id | The principal ID of the system-assigned managed identity |
| resource_group_name | The name of the resource group |
| location | The location/region of the resources |
| vnet_id | The ID of the virtual network |
| subnet_id | The ID of the subnet |
| load_balancer_id | The ID of the load balancer (if enabled) |
| load_balancer_public_ip | The public IP of the load balancer (if enabled) |
| load_balancer_backend_pool_id | The ID of the load balancer backend pool |
| autoscale_setting_id | The ID of the autoscale setting (if enabled) |

## Requirements

- Terraform >= 1.3.0
- Azure Provider ~> 3.116.0
- Random Provider ~> 3.6.0

## OS Image Examples

**Linux:**
- Ubuntu 22.04 LTS: `Canonical` / `0001-com-ubuntu-server-jammy` / `22_04-lts-gen2`
- Ubuntu 20.04 LTS: `Canonical` / `0001-com-ubuntu-server-focal` / `20_04-lts-gen2`
- Red Hat Enterprise Linux 8: `RedHat` / `RHEL` / `8-lvm-gen2`
- Debian 11: `Debian` / `debian-11` / `11-gen2`

**Windows:**
- Windows Server 2022: `MicrosoftWindowsServer` / `WindowsServer` / `2022-Datacenter`
- Windows Server 2019: `MicrosoftWindowsServer` / `WindowsServer` / `2019-Datacenter`
- Windows 11 Enterprise: `MicrosoftWindowsDesktop` / `Windows-11` / `win11-22h2-ent`

## Security Considerations

- SSH key authentication is enforced for Linux VMSS (password auth disabled)
- System-assigned managed identity is created for Azure service authentication
- Load balancer uses Standard SKU for enhanced security features
- Network security groups should be configured separately for workload-specific rules
- Consider using Azure Key Vault for storing admin passwords

## Performance Considerations

- Choose appropriate VM SKU for workload requirements
- Use Premium_LRS for production workloads requiring consistent performance
- Enable autoscaling to handle variable workloads efficiently
- Configure health probes with appropriate intervals and thresholds
- Use availability zones for production workloads requiring high availability

## Cost Optimization

- Use spot instances for non-critical, interruptible workloads (up to 90% savings)
- Configure autoscaling to scale down during low usage periods
- Choose appropriate VM SKU - avoid over-provisioning
- Consider Reserved Instances for predictable, long-term workloads
- Use Standard_LRS for non-production environments

## Troubleshooting

**VMSS instances not scaling:**
- Verify autoscaling is enabled and metrics are being collected
- Check CPU thresholds are appropriate for your workload
- Review autoscale activity logs in Azure Monitor

**Load balancer health probe failures:**
- Ensure application is listening on the configured port
- Verify health probe path returns HTTP 200 for Http probes
- Check NSG rules allow traffic from Azure Load Balancer (168.63.129.16)

**Spot instance evictions:**
- Review eviction policy and max bid price configuration
- Monitor Azure Spot pricing in your region
- Consider hybrid approach with regular and spot instances
