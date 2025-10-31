# Azure Virtual Machine Scale Set Building Block

This building block creates an Azure Virtual Machine Scale Set (VMSS) with comprehensive configuration options for scalable, highly available compute infrastructure. The VMSS is deployed into an existing spoke VNet, following Azure landing zone best practices.

## Features

- **Spoke Network Integration**: Deploys into existing spoke VNet and subnet
- **Linux and Windows Support**: Create scale sets for both operating systems
- **Auto-scaling**: CPU-based automatic scaling with configurable thresholds
- **Load Balancing**: Integrated Azure Load Balancer with health probes
- **High Availability**: Support for availability zones and fault domains
- **Flexible Upgrade Modes**: Manual, Automatic, or Rolling upgrade policies
- **Spot Instances**: Optional spot VMs for significant cost savings
- **Security**: Network Security Groups with customizable rules
- **Managed Identity**: System-assigned identity for secure Azure resource access
- **Boot Diagnostics**: Built-in boot diagnostics support
- **Custom Initialization**: Support for cloud-init (Linux) and PowerShell (Windows)

## Prerequisites

This module requires an existing spoke VNet and subnet. You can create these using the [spoke-network module](../../spoke-network).

## Usage

### Basic Linux Scale Set

```hcl
module "vmss" {
  source = "./modules/azure/vmss/buildingblock"

  vmss_name           = "my-app-vmss"
  resource_group_name = "my-resource-group"
  location            = "eastus"
  os_type             = "Linux"
  sku                 = "Standard_B2s"
  instances           = 3
  ssh_public_key      = file("~/.ssh/id_rsa.pub")

  # Existing spoke network
  vnet_name                = "spoke-vnet"
  vnet_resource_group_name = "network-rg"
  subnet_name              = "workload-subnet"

  tags = {
    Environment = "Production"
    Application = "WebApp"
  }
}
```

### Auto-scaling Web Application

```hcl
module "web_vmss" {
  source = "./modules/azure/vmss/buildingblock"

  vmss_name           = "web-app-vmss"
  resource_group_name = "web-rg"
  location            = "westeurope"

  os_type             = "Linux"
  sku                 = "Standard_D2s_v3"
  instances           = 2
  ssh_public_key      = var.ssh_public_key

  # Existing spoke network
  vnet_name                = "spoke-vnet-prod"
  vnet_resource_group_name = "network-rg"
  subnet_name              = "web-tier-subnet"

  enable_autoscaling        = true
  min_instances             = 2
  max_instances             = 10
  scale_out_cpu_threshold   = 75
  scale_in_cpu_threshold    = 25

  enable_load_balancer      = true
  enable_public_ip          = true
  frontend_port             = 80
  backend_port              = 80
  health_probe_protocol     = "Http"
  health_probe_port         = 80
  health_probe_request_path = "/health"

  upgrade_mode              = "Rolling"

  zones = ["1", "2", "3"]

  custom_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
    systemctl start nginx
    systemctl enable nginx
  EOF

  tags = {
    Environment = "Production"
    Application = "WebApp"
  }
}
```

### Windows Scale Set

```hcl
module "windows_vmss" {
  source = "./modules/azure/vmss/buildingblock"

  vmss_name           = "win-app-vmss"
  resource_group_name = "windows-rg"
  location            = "eastus"

  os_type             = "Windows"
  sku                 = "Standard_D2s_v3"
  instances           = 2
  admin_username      = "azureadmin"
  admin_password      = var.admin_password

  # Existing spoke network
  vnet_name                = "spoke-vnet"
  vnet_resource_group_name = "network-rg"
  subnet_name              = "app-subnet"

  image_publisher     = "MicrosoftWindowsServer"
  image_offer         = "WindowsServer"
  image_sku           = "2022-Datacenter"
  image_version       = "latest"

  enable_load_balancer = true
  backend_port         = 80
  frontend_port        = 80

  enable_rdp_access   = false

  tags = {
    Environment = "Production"
    OS          = "Windows"
  }
}
```

### Spot Instance Scale Set (Cost-Optimized)

```hcl
module "spot_vmss" {
  source = "./modules/azure/vmss/buildingblock"

  vmss_name           = "spot-compute-vmss"
  resource_group_name = "compute-rg"
  location            = "eastus"

  os_type             = "Linux"
  sku                 = "Standard_D2s_v3"
  instances           = 5
  ssh_public_key      = var.ssh_public_key

  # Existing spoke network
  vnet_name                = "spoke-vnet-dev"
  vnet_resource_group_name = "network-rg"
  subnet_name              = "compute-subnet"

  enable_spot_instances = true
  spot_eviction_policy  = "Deallocate"
  spot_max_bid_price    = -1

  enable_load_balancer  = false

  tags = {
    Environment = "Development"
    CostCenter  = "Engineering"
  }
}
```

### Integration with Spoke Network Module

```hcl
# First, create the spoke network
module "spoke_network" {
  source = "./modules/azure/spoke-network"

  vnet_name           = "spoke-vnet-prod"
  resource_group_name = "network-rg"
  location            = "eastus"
  address_space       = ["10.1.0.0/16"]

  subnets = {
    "web-tier-subnet" = {
      address_prefixes = ["10.1.1.0/24"]
    }
    "app-tier-subnet" = {
      address_prefixes = ["10.1.2.0/24"]
    }
  }
}

# Then deploy VMSS using the spoke network
module "web_vmss" {
  source = "./modules/azure/vmss/buildingblock"

  vmss_name           = "web-app-vmss"
  resource_group_name = "web-rg"
  location            = "eastus"

  os_type        = "Linux"
  sku            = "Standard_D2s_v3"
  instances      = 2
  ssh_public_key = var.ssh_public_key

  # Reference outputs from spoke network
  vnet_name                = module.spoke_network.vnet_name
  vnet_resource_group_name = module.spoke_network.resource_group_name
  subnet_name              = "web-tier-subnet"

  enable_load_balancer = true
  enable_public_ip     = true
  frontend_port        = 80
  backend_port         = 80

  tags = {
    Environment = "Production"
  }
}
```

## Best Practices

### Scaling Configuration

1. **Use Autoscaling**: Enable autoscaling for production workloads to handle traffic variations
2. **Set Appropriate Thresholds**: Configure CPU thresholds based on application characteristics
3. **Cooldown Periods**: Default 5-minute cooldown prevents rapid scaling oscillations

### High Availability

1. **Availability Zones**: Use 3 zones for maximum availability (99.99% SLA)
2. **Health Probes**: Configure application-specific health checks
3. **Rolling Upgrades**: Use rolling upgrade mode for zero-downtime deployments

### Security

1. **Disable Public Access**: Set `enable_ssh_access = false` and `enable_rdp_access = false`
2. **Use Azure Bastion**: Recommended for secure VM access
3. **Managed Identity**: Use system-assigned identity instead of storing credentials
4. **Network Security Groups**: Review and customize NSG rules for your workload

### Performance

1. **Choose Right SKU**: Select VM size based on workload requirements
2. **Premium Storage**: Use Premium_LRS for production I/O-intensive workloads
3. **Load Balancer SKU**: Use Standard SKU for production (required for zones)

### Cost Optimization

1. **Spot Instances**: Use for fault-tolerant, stateless workloads (70-90% savings)
2. **Right-Sizing**: Start with smaller SKUs and scale based on metrics
3. **Autoscaling**: Automatically reduce instances during low-traffic periods

## Limitations

- Single placement group limits scale set to 100 instances (set `single_placement_group = false` for 1000+ instances)
- Spot instances can be evicted with 30-second notice
- Rolling upgrade requires health probe configuration
- Windows VMs require admin password (stored as sensitive)

## Testing

Tests are included in `vmss.tftest.hcl`. Run with:

```bash
tofu test
```

## Resources Created

- Resource Group
- Network Security Group
- VM Scale Set (Linux or Windows)
- Load Balancer (optional)
- Public IP (optional)
- Autoscale Settings (optional)

**Note**: This module uses existing spoke VNet and subnet (not created by this module).

## Related Modules

- [azure-virtual-machine](../azure-virtual-machine/) - Single VM deployment
- [azure-bastion](../azure-bastion/) - Secure VM access
- [spoke-network](../spoke-network/) - Network infrastructure

## License

See repository root for license information.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | 4.18.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | 3.6.3 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_lb.vmss_lb](https://registry.terraform.io/providers/hashicorp/azurerm/4.18.0/docs/resources/lb) | resource |
| [azurerm_lb_backend_address_pool.vmss_backend_pool](https://registry.terraform.io/providers/hashicorp/azurerm/4.18.0/docs/resources/lb_backend_address_pool) | resource |
| [azurerm_lb_probe.vmss_health_probe](https://registry.terraform.io/providers/hashicorp/azurerm/4.18.0/docs/resources/lb_probe) | resource |
| [azurerm_lb_rule.vmss_lb_rule](https://registry.terraform.io/providers/hashicorp/azurerm/4.18.0/docs/resources/lb_rule) | resource |
| [azurerm_linux_virtual_machine_scale_set.vmss](https://registry.terraform.io/providers/hashicorp/azurerm/4.18.0/docs/resources/linux_virtual_machine_scale_set) | resource |
| [azurerm_monitor_autoscale_setting.vmss_autoscale](https://registry.terraform.io/providers/hashicorp/azurerm/4.18.0/docs/resources/monitor_autoscale_setting) | resource |
| [azurerm_network_security_group.vmss_nsg](https://registry.terraform.io/providers/hashicorp/azurerm/4.18.0/docs/resources/network_security_group) | resource |
| [azurerm_network_security_rule.allow_backend_port](https://registry.terraform.io/providers/hashicorp/azurerm/4.18.0/docs/resources/network_security_rule) | resource |
| [azurerm_network_security_rule.allow_rdp](https://registry.terraform.io/providers/hashicorp/azurerm/4.18.0/docs/resources/network_security_rule) | resource |
| [azurerm_network_security_rule.allow_ssh](https://registry.terraform.io/providers/hashicorp/azurerm/4.18.0/docs/resources/network_security_rule) | resource |
| [azurerm_public_ip.lb_public_ip](https://registry.terraform.io/providers/hashicorp/azurerm/4.18.0/docs/resources/public_ip) | resource |
| [azurerm_resource_group.vmss_rg](https://registry.terraform.io/providers/hashicorp/azurerm/4.18.0/docs/resources/resource_group) | resource |
| [azurerm_subnet_network_security_group_association.vmss_nsg_association](https://registry.terraform.io/providers/hashicorp/azurerm/4.18.0/docs/resources/subnet_network_security_group_association) | resource |
| [azurerm_windows_virtual_machine_scale_set.vmss](https://registry.terraform.io/providers/hashicorp/azurerm/4.18.0/docs/resources/windows_virtual_machine_scale_set) | resource |
| [random_string.resource_code](https://registry.terraform.io/providers/hashicorp/random/3.6.3/docs/resources/string) | resource |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/4.18.0/docs/data-sources/client_config) | data source |
| [azurerm_subnet.vmss_subnet](https://registry.terraform.io/providers/hashicorp/azurerm/4.18.0/docs/data-sources/subnet) | data source |
| [azurerm_subscription.current](https://registry.terraform.io/providers/hashicorp/azurerm/4.18.0/docs/data-sources/subscription) | data source |
| [azurerm_virtual_network.spoke_vnet](https://registry.terraform.io/providers/hashicorp/azurerm/4.18.0/docs/data-sources/virtual_network) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_admin_password"></a> [admin\_password](#input\_admin\_password) | The admin password for Windows VM instances (required for Windows) | `string` | `null` | no |
| <a name="input_admin_username"></a> [admin\_username](#input\_admin\_username) | The admin username for the VM instances | `string` | `"azureuser"` | no |
| <a name="input_backend_port"></a> [backend\_port](#input\_backend\_port) | Backend port for load balancer rule | `number` | `80` | no |
| <a name="input_custom_data"></a> [custom\_data](#input\_custom\_data) | Custom data script to run on VM initialization (cloud-init for Linux, PowerShell for Windows) | `string` | `null` | no |
| <a name="input_enable_autoscaling"></a> [enable\_autoscaling](#input\_enable\_autoscaling) | Enable autoscaling based on CPU metrics | `bool` | `false` | no |
| <a name="input_enable_boot_diagnostics"></a> [enable\_boot\_diagnostics](#input\_enable\_boot\_diagnostics) | Enable boot diagnostics for VM instances | `bool` | `true` | no |
| <a name="input_enable_load_balancer"></a> [enable\_load\_balancer](#input\_enable\_load\_balancer) | Enable Azure Load Balancer for the scale set | `bool` | `true` | no |
| <a name="input_enable_public_ip"></a> [enable\_public\_ip](#input\_enable\_public\_ip) | Enable public IP for the load balancer | `bool` | `false` | no |
| <a name="input_enable_rdp_access"></a> [enable\_rdp\_access](#input\_enable\_rdp\_access) | Enable RDP access (port 3389) through NSG for Windows VMs | `bool` | `false` | no |
| <a name="input_enable_spot_instances"></a> [enable\_spot\_instances](#input\_enable\_spot\_instances) | Enable spot instances for significant cost savings (VMs can be evicted) | `bool` | `false` | no |
| <a name="input_enable_ssh_access"></a> [enable\_ssh\_access](#input\_enable\_ssh\_access) | Enable SSH access (port 22) through NSG for Linux VMs | `bool` | `false` | no |
| <a name="input_frontend_port"></a> [frontend\_port](#input\_frontend\_port) | Frontend port for load balancer rule | `number` | `80` | no |
| <a name="input_health_probe_port"></a> [health\_probe\_port](#input\_health\_probe\_port) | Port for health probe - required when upgrade\_mode is Automatic or Rolling | `number` | `80` | no |
| <a name="input_health_probe_protocol"></a> [health\_probe\_protocol](#input\_health\_probe\_protocol) | Protocol for health probe (Http, Https, Tcp) - required when upgrade\_mode is Automatic or Rolling | `string` | `"Http"` | no |
| <a name="input_health_probe_request_path"></a> [health\_probe\_request\_path](#input\_health\_probe\_request\_path) | Request path for HTTP/HTTPS health probe - required for Http/Https protocol | `string` | `"/"` | no |
| <a name="input_image_offer"></a> [image\_offer](#input\_image\_offer) | The offer of the image | `string` | `"0001-com-ubuntu-server-jammy"` | no |
| <a name="input_image_publisher"></a> [image\_publisher](#input\_image\_publisher) | The publisher of the image | `string` | `"Canonical"` | no |
| <a name="input_image_sku"></a> [image\_sku](#input\_image\_sku) | The SKU of the image | `string` | `"22_04-lts-gen2"` | no |
| <a name="input_image_version"></a> [image\_version](#input\_image\_version) | The version of the image | `string` | `"latest"` | no |
| <a name="input_instances"></a> [instances](#input\_instances) | The initial number of instances in the scale set | `number` | `2` | no |
| <a name="input_load_balancer_sku"></a> [load\_balancer\_sku](#input\_load\_balancer\_sku) | SKU of the Load Balancer (Basic or Standard) | `string` | `"Standard"` | no |
| <a name="input_location"></a> [location](#input\_location) | The Azure region where resources will be deployed | `string` | n/a | yes |
| <a name="input_max_instances"></a> [max\_instances](#input\_max\_instances) | Maximum number of instances when autoscaling is enabled | `number` | `10` | no |
| <a name="input_min_instances"></a> [min\_instances](#input\_min\_instances) | Minimum number of instances when autoscaling is enabled | `number` | `2` | no |
| <a name="input_os_disk_size_gb"></a> [os\_disk\_size\_gb](#input\_os\_disk\_size\_gb) | The size of the OS disk in GB | `number` | `30` | no |
| <a name="input_os_disk_storage_type"></a> [os\_disk\_storage\_type](#input\_os\_disk\_storage\_type) | The storage account type for the OS disk | `string` | `"Standard_LRS"` | no |
| <a name="input_os_type"></a> [os\_type](#input\_os\_type) | The operating system type (Linux or Windows) | `string` | `"Linux"` | no |
| <a name="input_overprovision"></a> [overprovision](#input\_overprovision) | Overprovision VMs to improve deployment success rate | `bool` | `true` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | The name of the resource group where resources will be created | `string` | n/a | yes |
| <a name="input_scale_in_cpu_threshold"></a> [scale\_in\_cpu\_threshold](#input\_scale\_in\_cpu\_threshold) | CPU percentage threshold to trigger scale in | `number` | `25` | no |
| <a name="input_scale_out_cpu_threshold"></a> [scale\_out\_cpu\_threshold](#input\_scale\_out\_cpu\_threshold) | CPU percentage threshold to trigger scale out | `number` | `75` | no |
| <a name="input_single_placement_group"></a> [single\_placement\_group](#input\_single\_placement\_group) | Limit scale set to single placement group (max 100 instances) | `bool` | `true` | no |
| <a name="input_sku"></a> [sku](#input\_sku) | The SKU of the Virtual Machine Scale Set (instance size) | `string` | `"Standard_B2s"` | no |
| <a name="input_spot_eviction_policy"></a> [spot\_eviction\_policy](#input\_spot\_eviction\_policy) | Eviction policy for spot instances (Deallocate or Delete) | `string` | `"Deallocate"` | no |
| <a name="input_spot_max_bid_price"></a> [spot\_max\_bid\_price](#input\_spot\_max\_bid\_price) | Maximum price per hour for spot instances. -1 means pay up to on-demand price | `number` | `-1` | no |
| <a name="input_ssh_public_key"></a> [ssh\_public\_key](#input\_ssh\_public\_key) | SSH public key for Linux VM authentication (required for Linux) | `string` | `null` | no |
| <a name="input_subnet_name"></a> [subnet\_name](#input\_subnet\_name) | The name of the existing subnet where VMSS will be deployed | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_upgrade_mode"></a> [upgrade\_mode](#input\_upgrade\_mode) | Upgrade policy mode for the scale set (Automatic, Manual, Rolling) | `string` | `"Manual"` | no |
| <a name="input_vmss_name"></a> [vmss\_name](#input\_vmss\_name) | The name of the Virtual Machine Scale Set | `string` | n/a | yes |
| <a name="input_vnet_name"></a> [vnet\_name](#input\_vnet\_name) | The name of the existing virtual network (spoke VNet) | `string` | n/a | yes |
| <a name="input_vnet_resource_group_name"></a> [vnet\_resource\_group\_name](#input\_vnet\_resource\_group\_name) | The name of the resource group containing the virtual network | `string` | n/a | yes |
| <a name="input_zones"></a> [zones](#input\_zones) | Availability zones to spread instances across (e.g., [1, 2, 3]) | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_autoscaling_enabled"></a> [autoscaling\_enabled](#output\_autoscaling\_enabled) | Whether autoscaling is enabled |
| <a name="output_current_instances"></a> [current\_instances](#output\_current\_instances) | The configured number of instances |
| <a name="output_instance_size"></a> [instance\_size](#output\_instance\_size) | The SKU/size of VM instances |
| <a name="output_load_balancer_frontend_ip"></a> [load\_balancer\_frontend\_ip](#output\_load\_balancer\_frontend\_ip) | The frontend IP address of the load balancer (public or private) |
| <a name="output_load_balancer_id"></a> [load\_balancer\_id](#output\_load\_balancer\_id) | The ID of the load balancer (if enabled) |
| <a name="output_location"></a> [location](#output\_location) | The Azure region where resources are deployed |
| <a name="output_public_ip_address"></a> [public\_ip\_address](#output\_public\_ip\_address) | The public IP address of the load balancer (if enabled) |
| <a name="output_resource_group_name"></a> [resource\_group\_name](#output\_resource\_group\_name) | The name of the resource group |
| <a name="output_subnet_id"></a> [subnet\_id](#output\_subnet\_id) | The ID of the subnet |
| <a name="output_summary"></a> [summary](#output\_summary) | Markdown summary output of the building block |
| <a name="output_vmss_id"></a> [vmss\_id](#output\_vmss\_id) | The ID of the Virtual Machine Scale Set |
| <a name="output_vmss_identity_principal_id"></a> [vmss\_identity\_principal\_id](#output\_vmss\_identity\_principal\_id) | The Principal ID of the system-assigned managed identity |
| <a name="output_vmss_name"></a> [vmss\_name](#output\_vmss\_name) | The name of the Virtual Machine Scale Set |
| <a name="output_vnet_id"></a> [vnet\_id](#output\_vnet\_id) | The ID of the virtual network |
| <a name="output_vnet_name"></a> [vnet\_name](#output\_vnet\_name) | The name of the virtual network |
<!-- END_TF_DOCS -->