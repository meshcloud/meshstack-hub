# IONOS DCD Virtual Machine - App Team Guide

This guide explains how to use the IONOS DCD Virtual Machine building block to deploy virtual machines to your IONOS DCD environment.

## Quick Start

### 1. Deploy Your First VM

```hcl
module "my_vm" {
  source = "path/to/ionos/dcd-vm/buildingblock"

  datacenter_id = "your-datacenter-id"
  vm_name       = "my-web-server"
  template      = "medium"
}
```

### 2. Get Your VM Details

```bash
terraform output
```

Output shows:
- VM ID
- Public IP address (if assigned)
- Network details
- Storage information

## Common Use Cases

### Web Server Deployment

```hcl
module "web_server" {
  source = "path/to/ionos/dcd-vm/buildingblock"

  datacenter_id = "your-datacenter-id"
  vm_name       = "web-server-prod"
  template      = "medium"
  
  # Automatically gets public IP for web traffic
  public_ip_required = true
}

output "web_server_ip" {
  value = module.web_server.public_ips[0]
}
```

### Database Server with Extra Storage

```hcl
module "database_server" {
  source = "path/to/ionos/dcd-vm/buildingblock"

  datacenter_id = "your-datacenter-id"
  vm_name       = "database-prod"
  template      = "large"

  additional_data_disks = [
    {
      name    = "db-data"
      size_gb = 500
    }
  ]

  public_ip_required = false  # No internet access needed
}
```

### Development/Testing Environment

```hcl
module "dev_vm" {
  source = "path/to/ionos/dcd-vm/buildingblock"

  datacenter_id = "your-datacenter-id"
  vm_name       = "dev-environment"
  template      = "small"  # Cost-effective for testing
  
  public_ip_required = true
}
```

### Custom High-Performance Server

```hcl
module "high_perf_server" {
  source = "path/to/ionos/dcd-vm/buildingblock"

  datacenter_id = "your-datacenter-id"
  vm_name       = "high-perf-app"
  template      = "custom"

  vm_specs = {
    cpu_cores    = 16
    memory_mb    = 32768
    storage_gb   = 1000
    storage_type = "SSD"
    os_image     = "ubuntu-22.04"
  }
}
```

## VM Sizing Guide

Choose the right VM size for your workload:

### Small (2 CPU, 4GB RAM, 50GB Storage)
- **Best for**: Web front-ends, small applications, testing
- **Cost**: $ (lowest)
- **Example**: Apache web server, small Node.js app

### Medium (4 CPU, 8GB RAM, 100GB Storage)
- **Best for**: Standard applications, APIs, small databases
- **Cost**: $$ (moderate)
- **Example**: Node.js/Python API, WordPress, small Postgres

### Large (8 CPU, 16GB RAM, 200GB Storage)
- **Best for**: Large databases, heavy processing, high-traffic apps
- **Cost**: $$$ (highest)
- **Example**: MySQL/PostgreSQL database, Java application

### Custom
- **Best for**: Specialized needs outside standard templates
- **Cost**: Variable based on specs
- **Example**: Very high CPU, specialized workloads

## Operating System Selection

Common operating systems available:

| OS | Best For | Notes |
|----|----------|-------|
| `ubuntu-22.04` | General purpose, web apps | Latest LTS, recommended |
| `ubuntu-20.04` | Stability, production | Previous LTS |
| `debian-11` | Lightweight, servers | Conservative, stable |
| `centos-8` | Enterprise, CentOS users | Enterprise-focused |
| `windows-server-2022` | Windows workloads | Includes licensing |

## Networking Explained

### Default Network Setup
When you deploy a VM, it automatically:
1. Creates a network (LAN) for the VM
2. Assigns a private IP via DHCP
3. Allocates a public IP (optional)
4. Configures automatic networking

### Multiple VMs on Same Network

Connect multiple VMs to the same network:

```hcl
# Create shared network
resource "ionoscloud_lan" "shared" {
  datacenter_id = var.datacenter_id
  name          = "shared-network"
  public        = false  # Internal only
}

# Deploy web server
module "web" {
  source = "path/to/ionos/dcd-vm/buildingblock"
  
  datacenter_id           = var.datacenter_id
  vm_name                 = "web-01"
  template                = "medium"
  create_network_interface = true
  network_id              = ionoscloud_lan.shared.id
  public_ip_required      = true
}

# Deploy app server on same network
module "app" {
  source = "path/to/ionos/dcd-vm/buildingblock"
  
  datacenter_id           = var.datacenter_id
  vm_name                 = "app-01"
  template                = "medium"
  create_network_interface = true
  network_id              = ionoscloud_lan.shared.id
  public_ip_required      = false  # Private only
}
```

## Storage Guide

### Boot Volume
- Automatically created with OS image
- Size based on template or custom specs
- System disk for your operating system

### Data Volumes
Add extra storage for databases, files, or application data:

```hcl
additional_data_disks = [
  {
    name    = "app-data"
    size_gb = 100
  },
  {
    name    = "backups"
    size_gb = 500
  }
]
```

### Mounting Data Disks in Your OS

After VM is created, connect and mount your data disks:

**Ubuntu/Debian:**
```bash
# List available disks
lsblk

# Format (first time only)
sudo mkfs.ext4 /dev/vdb

# Mount
sudo mkdir -p /mnt/appdata
sudo mount /dev/vdb /mnt/appdata

# Make permanent in /etc/fstab
echo "/dev/vdb /mnt/appdata ext4 defaults 0 0" | sudo tee -a /etc/fstab
```

**CentOS:**
```bash
# Same steps as Ubuntu/Debian
sudo mkfs.ext4 /dev/vdb
sudo mkdir -p /mnt/appdata
sudo mount /dev/vdb /mnt/appdata
```

## Cost Optimization

### Save Money

1. **Use Small VMs for Dev/Test**: Medium/Large only for production
2. **Right-size Your Server**: Don't over-provision resources
3. **Use Data Disks Efficiently**: Only allocate needed storage
4. **Stop Unused VMs**: Remove VMs you're not using

### Cost Examples (Approximate Monthly)
- Small VM: ~$10-15
- Medium VM: ~$20-30
- Large VM: ~$40-60
- Extra 100GB storage: ~$5

## Deployment Examples

### Deploying Multiple Web Servers

```hcl
module "web_servers" {
  for_each = {
    "web-01" = {}
    "web-02" = {}
    "web-03" = {}
  }

  source = "path/to/ionos/dcd-vm/buildingblock"

  datacenter_id = var.datacenter_id
  vm_name       = each.key
  template      = "medium"
  
  public_ip_required = true
}

output "web_servers" {
  value = {
    for name, vm in module.web_servers : name => {
      id       = vm.server_id
      public_ip = vm.public_ips[0]
    }
  }
}
```

### Complete 3-Tier Application Stack

```hcl
# Web tier
module "web" {
  source = "path/to/ionos/dcd-vm/buildingblock"
  
  datacenter_id  = var.datacenter_id
  vm_name        = "web-server"
  template       = "medium"
  public_ip_required = true
}

# App tier
module "app" {
  source = "path/to/ionos/dcd-vm/buildingblock"
  
  datacenter_id  = var.datacenter_id
  vm_name        = "app-server"
  template       = "medium"
  public_ip_required = false
}

# Database tier
module "database" {
  source = "path/to/ionos/dcd-vm/buildingblock"
  
  datacenter_id  = var.datacenter_id
  vm_name        = "database"
  template       = "large"
  public_ip_required = false
  
  additional_data_disks = [{
    name    = "database"
    size_gb = 500
  }]
}
```

## Troubleshooting

### VM Creation Failed

**Problem**: Terraform apply fails with resource error

**Solution**:
1. Check datacenter has available resources
2. Verify IONOS_TOKEN is valid
3. Ensure VM name is unique in datacenter
4. Try again in 5 minutes

### Can't Connect to VM

**Problem**: Cannot SSH/RDP to the VM

**Solution**:
1. Verify public IP was assigned: `terraform output`
2. Wait 2-5 minutes for VM to fully boot
3. Check security group/firewall rules
4. Verify correct OS username (ubuntu/admin/root)

### Data Disk Not Visible

**Problem**: Data disk attached but not mounted in OS

**Solution**:
1. SSH/RDP into VM
2. List disks: `lsblk`
3. Format: `sudo mkfs.ext4 /dev/vdb`
4. Mount: `sudo mount /dev/vdb /mnt/data`
5. Add to `/etc/fstab` for persistence

### Public IP Not Assigned

**Problem**: No public IP despite setting `public_ip_required = true`

**Solution**:
1. Check terraform outputs: `terraform output public_ips`
2. Verify `public_ip_required = true` in configuration
3. Wait 5-10 minutes for IP allocation
4. Check IONOS DCD console for IP status

## Shared Responsibility Matrix

| Responsibility | You | IONOS |
|---|---|---|
| **Infrastructure** | | |
| VM provisioning | ✅ | ✅ |
| Network setup | ✅ | ✅ |
| Storage provisioning | ✅ | ✅ |
| Physical security | | ✅ |
| **Operations** | | |
| OS updates | ✅ | |
| Firewall rules | ✅ | |
| Data backups | ✅ | |
| Performance monitoring | ✅ | ✅ |
| **Security** | | |
| SSH key management | ✅ | |
| Access controls | ✅ | ✅ |
| Data encryption | ✅ | |
| Compliance | ✅ | ✅ |

## Best Practices

### Do ✅
- Use appropriate VM size for your workload
- Enable public IPs only when needed
- Monitor VM performance and costs
- Take regular backups of data disks
- Use meaningful VM naming
- Document your infrastructure
- Use templates for consistency

### Don't ❌
- Don't over-provision resources (costs money)
- Don't leave unnecessary public IPs active
- Don't ignore security updates
- Don't forget to backup important data
- Don't use weak root passwords
- Don't deploy without a backup strategy
- Don't mix production and testing on same VM

## Getting Help

### Documentation
- Full technical docs: See README.md
- IONOS API docs: https://api.ionos.com/docs

### Support
- Contact your cloud admin team
- IONOS support portal
- Review IONOS DCD logs in console

## What's Next?

After deploying your VM:

1. **Access Your VM**: SSH/RDP to the public IP
2. **Install Software**: Set up your application
3. **Configure Firewall**: Set up security rules
4. **Enable Monitoring**: Monitor performance
5. **Set Up Backups**: Protect your data
6. **Document Setup**: Record your configuration

## Environment Variables

Required before running Terraform:

```bash
# Set your IONOS API token
export IONOS_TOKEN="your-ionos-api-token-here"

# Verify it's set
echo $IONOS_TOKEN
```

## Terraform Workflow

```bash
# 1. Initialize Terraform
terraform init

# 2. Plan your deployment
terraform plan

# 3. Deploy
terraform apply

# 4. View outputs
terraform output

# 5. Get public IP
terraform output -raw public_ips

# 6. Destroy when done (optional)
terraform destroy
```

## FAQ

**Q: Can I change VM size after creation?**
A: Not directly. Destroy and recreate with new size.

**Q: Can I add storage after creation?**
A: Yes! Use `additional_data_disks` or add manually in IONOS console.

**Q: How long does deployment take?**
A: Usually 2-5 minutes from terraform apply to ready.

**Q: Can I use Windows?**
A: Yes! Use `os_image = "windows-server-2022"` or 2019.

**Q: Do you provide backups?**
A: No. You must implement your own backup strategy.

**Q: Can I resize storage?**
A: Boot volume: no. Data disks: can add new ones.

**Q: What if I run out of space?**
A: Add new data disk via additional_data_disks or terraform apply.

**Q: Can I pause a VM?**
A: Yes, via IONOS console or API. Terraform state remains.
