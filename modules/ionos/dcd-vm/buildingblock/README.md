---
name: IONOS DCD Virtual Machine
supportedPlatforms:
  - ionos
description: Deploys and manages virtual machines in IONOS Data Center Designer environments with flexible configuration options, custom networking, and additional data disk support.
---

# IONOS DCD Virtual Machine Building Block

This building block deploys and manages virtual machines in IONOS Data Center Designer (DCD) environments. It provides flexible VM configuration with preset templates, optional network provisioning, and support for additional data disks.

## Features

- **Template Presets**: Quick deployment with predefined VM sizes (small, medium, large)
- **Custom Configuration**: Full control over CPU, memory, storage, and OS image
- **Network Management**: Optional LAN creation or attach to existing networks
- **Public IP Support**: Configurable public IP allocation for internet access
- **Data Disks**: Support for additional data volumes attached to the VM
- **Auto-provisioning**: Automatic volume, NIC, and server resource creation

## Prerequisites

- IONOS Cloud account with DCD enabled
- IONOS API token (set as `IONOS_TOKEN` environment variable)
- Existing IONOS DCD datacenter (create via `ionos/dcd/buildingblock` or existing datacenter ID)
- Terraform >= 1.0

## Architecture

```
┌──────────────────────┐
│  IONOS DCD VM Module │
├──────────────────────┤
│                      │
│ ┌──────────────────┐ │
│ │ VM Server        │ │
│ │ • CPU/Memory     │ │
│ │ • Boot Volume    │ │
│ │ • Network Attach │ │
│ └──────────────────┘ │
│                      │
│ ┌──────────────────┐ │
│ │ Network (LAN)    │ │
│ │ • Create or use  │ │
│ │   existing       │ │
│ │ • DHCP support   │ │
│ │ • Public IP opt. │ │
│ └──────────────────┘ │
│                      │
│ ┌──────────────────┐ │
│ │ Storage Volumes  │ │
│ │ • Boot volume    │ │
│ │ • Data volumes   │ │
│ │ • SSD/HDD option │ │
│ └──────────────────┘ │
│                      │
└──────────────────────┘
         │
         └──► IONOS Cloud API
```

## Usage

### Basic Example - Using Preset Template

```hcl
module "ionos_vm" {
  source = "path/to/ionos/dcd-vm/buildingblock"

  datacenter_id = "abc123def456"
  vm_name       = "web-server-01"
  template      = "medium"

  # Optional configuration
  public_ip_required = true
  create_network_interface = true
}
```

### Custom Configuration Example

```hcl
module "ionos_vm_custom" {
  source = "path/to/ionos/dcd-vm/buildingblock"

  datacenter_id = "abc123def456"
  vm_name       = "database-server"
  template      = "custom"

  vm_specs = {
    cpu_cores    = 8
    memory_mb    = 16384
    storage_gb   = 500
    storage_type = "SSD"
    os_image     = "ubuntu-22.04"
  }

  public_ip_required = true
}
```

### Advanced Example - With Data Disks

```hcl
module "ionos_vm_with_disks" {
  source = "path/to/ionos/dcd-vm/buildingblock"

  datacenter_id = "abc123def456"
  vm_name       = "app-server"
  template      = "large"

  additional_data_disks = [
    {
      name         = "data-1"
      size_gb      = 100
      storage_type = "SSD"
    },
    {
      name         = "data-2"
      size_gb      = 500
      storage_type = "SSD"
    }
  ]

  public_ip_required = true
}
```

### Using Existing Network

```hcl
module "ionos_vm_existing_network" {
  source = "path/to/ionos/dcd-vm/buildingblock"

  datacenter_id = "abc123def456"
  vm_name       = "internal-server"
  template      = "small"

  create_network_interface = true
  network_id              = "existing-lan-id"
  public_ip_required      = false
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `datacenter_id` | ID of the IONOS datacenter | `string` | - | yes |
| `vm_name` | Name of the virtual machine | `string` | - | yes |
| `template` | VM template (small, medium, large, custom) | `string` | `"custom"` | no |
| `vm_specs` | Custom VM specifications for custom template | `object` | `null` | conditional |
| `create_network_interface` | Create new network interface | `bool` | `true` | no |
| `network_id` | Existing network ID to attach to | `string` | `null` | no |
| `public_ip_required` | Allocate public IP address | `bool` | `true` | no |
| `additional_data_disks` | Additional data volumes to attach | `list(object)` | `[]` | no |
| `tags` | Tags to apply to resources | `map(string)` | `{}` | no |

### VM Specifications Format

When using `template = "custom"`, provide `vm_specs` with the following structure:

```hcl
vm_specs = {
  cpu_cores        = number      # 1-96 cores
  memory_mb        = number      # 1-1048576 MB
  storage_gb       = number      # 1-65536 GB
  storage_type     = string      # "SSD" or "HDD"
  os_image         = string      # OS image name (e.g., "ubuntu-22.04", "debian-11", "centos-8")
}
```

### Template Presets

| Template | CPU Cores | Memory | Storage | Type |
|----------|-----------|--------|---------|------|
| **small** | 2 | 4 GB | 50 GB | SSD |
| **medium** | 4 | 8 GB | 100 GB | SSD |
| **large** | 8 | 16 GB | 200 GB | SSD |

## Supported OS Images

IONOS provides the following OS images:

- `ubuntu-22.04`
- `ubuntu-20.04`
- `debian-11`
- `debian-10`
- `centos-8`
- `centos-7`
- `windows-server-2022`
- `windows-server-2019`

## Outputs

| Name | Description |
|------|-------------|
| `server_id` | ID of the created IONOS server |
| `server_name` | Name of the created server |
| `datacenter_id` | ID of the datacenter |
| `primary_nic_id` | ID of the primary network interface |
| `boot_volume_id` | ID of the boot/system volume |
| `data_volumes` | Map of data volume IDs by name |
| `public_ipblock_id` | ID of the reserved public IP block (if requested) |
| `public_ips` | List of reserved public IP addresses (if requested) |
| `vm_specs` | The effective VM specifications applied |
| `boot_cdrom_id` | ID of the boot CDROM |
| `server_details` | Complete server resource details |
| `network_configuration` | Network configuration details |

### Example Output Access

```hcl
# Get the server ID
output "vm_id" {
  value = module.ionos_vm.server_id
}

# Get public IP
output "public_ip" {
  value = var.public_ip_required ? module.ionos_vm.public_ips[0] : "No public IP assigned"
}

# Get effective specs
output "vm_configuration" {
  value = module.ionos_vm.vm_specs
}
```

## Network Configuration

### Creating New Network (Default)

When `create_network_interface = true` and `network_id = null`:
- A new LAN is created automatically
- Public IP connectivity available if `public_ip_required = true`
- DHCP is enabled by default

### Attaching to Existing Network

When `create_network_interface = true` and `network_id` is provided:
- The VM attaches to the specified existing LAN
- Public IP still allocated if `public_ip_required = true`

### Private Network Only

When `create_network_interface = false`:
- No network interface is created
- VM is isolated (not recommended for most use cases)
- Requires `network_id` to be null

## Storage Configuration

### Boot/System Volume

- Automatically created from selected OS image
- Size determined by template or `vm_specs`
- Type: SSD or HDD based on configuration
- Bus: VIRTIO

### Data Volumes

Add additional storage with the `additional_data_disks` variable:

```hcl
additional_data_disks = [
  {
    name         = "database-storage"
    size_gb      = 500
    storage_type = "SSD"
  }
]
```

Each data disk:
- Is created as a separate volume
- Gets attached to the VM
- Uses VIRTIO bus
- Can be detached and reused

## Troubleshooting

### Issue: Authentication Error

**Symptom**: `Error authenticating with IONOS API`

**Solution**:
1. Verify `IONOS_TOKEN` environment variable is set
2. Check token has sufficient permissions
3. Verify token hasn't expired
4. Test with `ionoscloud` CLI: `ionoscloud auth login`

### Issue: Datacenter Not Found

**Symptom**: `datacenter_id not found or invalid`

**Solution**:
1. Verify datacenter ID is correct
2. Check datacenter exists in your IONOS account
3. Verify datacenter is in accessible region
4. Use `ionoscloud datacenter list` to view available datacenters

### Issue: Insufficient Resources

**Symptom**: `Datacenter does not have sufficient resources`

**Solution**:
1. Try a smaller VM template
2. Reduce custom CPU/memory specifications
3. Check datacenter capacity
4. Wait and retry in a few minutes
5. Try a different datacenter location

### Issue: Invalid VM Name

**Symptom**: `VM name must be between 1 and 63 characters`

**Solution**:
1. Use shorter VM name (max 63 characters)
2. Remove special characters if present
3. Use alphanumeric characters and hyphens only

### Issue: OS Image Not Found

**Symptom**: `OS image not found or unavailable`

**Solution**:
1. Verify OS image name spelling (case-sensitive)
2. Use supported images from list above
3. Check image availability in your datacenter location
4. Try a different OS version

## Important Notes

- **VM Name Uniqueness**: VM names must be unique within the datacenter
- **Network Configuration**: At least one network interface is recommended
- **Public IPs**: Public IP allocation is optional but recommended for internet access
- **Boot Time**: Initial VM provisioning may take 2-5 minutes
- **Resource Limits**: Cannot exceed datacenter resource quotas
- **Cost Impact**: Resources incur charges based on IONOS pricing
- **Data Persistence**: Data volumes persist across VM restarts

## Integration with Other Modules

### With DCD Building Block

```hcl
# First create datacenter
module "dcd_env" {
  source = "path/to/ionos/dcd/buildingblock"
  
  datacenter_name = "production"
  datacenter_location = "de/fra"
  users = local.users
}

# Then deploy VM to that datacenter
module "vm" {
  source = "path/to/ionos/dcd-vm/buildingblock"
  
  datacenter_id = module.dcd_env.datacenter_id
  vm_name = "web-server"
  template = "medium"
}
```

### Multiple VMs in Same Datacenter

```hcl
module "vms" {
  for_each = {
    web-01 = { template = "medium", disks = [] }
    web-02 = { template = "medium", disks = [] }
    db-01  = { template = "large", disks = [{name = "data", size_gb = 500}] }
  }

  source = "path/to/ionos/dcd-vm/buildingblock"
  
  datacenter_id = var.datacenter_id
  vm_name = each.key
  template = each.value.template
  additional_data_disks = each.value.disks
}
```

## Best Practices

1. **Use Templates for Common Sizes**: Leverage `small`, `medium`, `large` for typical deployments
2. **Custom Specs for Specific Needs**: Use `custom` template only when needed
3. **Separate Networks**: Create separate LANs for different tiers (web, app, database)
4. **Data Backup**: Implement backup strategy for data volumes
5. **Monitoring**: Enable IONOS monitoring on VMs after creation
6. **Security**: Configure firewall rules after VM deployment
7. **Documentation**: Label VMs and networks clearly with tags
8. **Resource Naming**: Use consistent naming conventions for resources

## Version Requirements

| Component | Version |
|-----------|---------|
| Terraform | >= 1.0 |
| IONOS Provider | ~> 6.4.0 |

## Limitations

- Maximum of 96 CPU cores per VM
- Maximum of 1 TB RAM per VM
- Maximum of 64 TB storage per VM
- Only LINUX license type supported in current implementation
- VIRTIO bus required for all disks

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_ionoscloud"></a> [ionoscloud](#requirement\_ionoscloud) | ~> 6.4.0 |

## Resources

| Name | Type |
|------|------|
| [ionoscloud_cdrom.main](https://registry.terraform.io/providers/ionos-cloud/ionoscloud/latest/docs/resources/cdrom) | resource |
| [ionoscloud_ipblock.main](https://registry.terraform.io/providers/ionos-cloud/ionoscloud/latest/docs/resources/ipblock) | resource |
| [ionoscloud_lan.main](https://registry.terraform.io/providers/ionos-cloud/ionoscloud/latest/docs/resources/lan) | resource |
| [ionoscloud_nic.main](https://registry.terraform.io/providers/ionos-cloud/ionoscloud/latest/docs/resources/nic) | resource |
| [ionoscloud_server.main](https://registry.terraform.io/providers/ionos-cloud/ionoscloud/latest/docs/resources/server) | resource |
| [ionoscloud_server_volume.data](https://registry.terraform.io/providers/ionos-cloud/ionoscloud/latest/docs/resources/server_volume) | resource |
| [ionoscloud_volume.boot](https://registry.terraform.io/providers/ionos-cloud/ionoscloud/latest/docs/resources/volume) | resource |
| [ionoscloud_volume.data](https://registry.terraform.io/providers/ionos-cloud/ionoscloud/latest/docs/resources/volume) | resource |
| [ionoscloud_lan.existing](https://registry.terraform.io/providers/ionos-cloud/ionoscloud/latest/docs/data-sources/lan) | data source |

<!-- END_TF_DOCS -->
