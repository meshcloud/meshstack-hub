# IONOS DCD Virtual Machine - Integration Examples

This file shows how to integrate the IONOS DCD VM building block with other IONOS modules.

## Complete Integration: DCD + VM Deployment

### Step 1: Create Datacenter and Users

```hcl
# variables.tf
variable "default_user_password" {
  description = "Default password for IONOS users"
  type        = string
  sensitive   = true
}

# main.tf
module "ionos_users" {
  source = "./modules/ionos/user-management/buildingblock"

  default_user_password = var.default_user_password
  force_sec_auth        = true

  users = [
    {
      meshIdentifier = "dev-001"
      username       = "john.doe"
      firstName      = "John"
      lastName       = "Doe"
      email          = "john.doe@company.com"
      euid           = "john.doe"
      roles          = ["user"]
    },
    {
      meshIdentifier = "admin-001"
      username       = "jane.smith"
      firstName      = "Jane"
      lastName       = "Smith"
      email          = "jane.smith@company.com"
      euid           = "jane.smith"
      roles          = ["admin"]
    }
  ]
}

module "dcd_environment" {
  source = "./modules/ionos/dcd/buildingblock"

  datacenter_name = "production"
  datacenter_location = "de/fra"
  
  users = module.ionos_users.users
}
```

### Step 2: Deploy VMs to Datacenter

```hcl
# Deploy web server
module "web_server" {
  source = "./modules/ionos/dcd-vm/buildingblock"

  datacenter_id = module.dcd_environment.datacenter_id
  vm_name       = "web-prod-01"
  template      = "medium"
  
  public_ip_required = true
}

# Deploy app server
module "app_server" {
  source = "./modules/ionos/dcd-vm/buildingblock"

  datacenter_id = module.dcd_environment.datacenter_id
  vm_name       = "app-prod-01"
  template      = "large"
  
  public_ip_required = false
}

# Deploy database with extra storage
module "database_server" {
  source = "./modules/ionos/dcd-vm/buildingblock"

  datacenter_id = module.dcd_environment.datacenter_id
  vm_name       = "db-prod-01"
  template      = "large"
  
  additional_data_disks = [
    {
      name    = "database"
      size_gb = 1000
    }
  ]
  
  public_ip_required = false
}
```

## Multi-Environment Deployment

Deploy development, staging, and production environments with VMs:

```hcl
locals {
  environments = {
    dev = {
      datacenter_name = "development"
      vm_template     = "small"
      vm_count        = 2
    }
    staging = {
      datacenter_name = "staging"
      vm_template     = "medium"
      vm_count        = 3
    }
    prod = {
      datacenter_name = "production"
      vm_template     = "large"
      vm_count        = 5
    }
  }
}

# Create datacenters
module "datacenters" {
  for_each = local.environments

  source = "./modules/ionos/dcd/buildingblock"

  datacenter_name = each.value.datacenter_name
  datacenter_location = "de/fra"
  
  users = local.all_users
}

# Create VMs for each environment
module "environment_vms" {
  for_each = local.environments

  source = "./modules/ionos/dcd-vm/buildingblock"

  datacenter_id = module.datacenters[each.key].datacenter_id
  vm_name       = "${each.key}-vm"
  template      = each.value.vm_template
  
  public_ip_required = each.key != "prod" ? true : false
}
```

## Microservices Architecture

Deploy a complete microservices stack:

```hcl
# Create shared datacenter
module "microservices_dc" {
  source = "./modules/ionos/dcd/buildingblock"

  datacenter_name = "microservices"
  datacenter_location = "de/fra"
  
  users = local.dev_team_users
}

# Deploy services on separate VMs
module "services" {
  for_each = {
    "api-gateway" = {
      template = "medium"
      public   = true
    }
    "user-service" = {
      template = "medium"
      public   = false
    }
    "order-service" = {
      template = "medium"
      public   = false
    }
    "payment-service" = {
      template = "medium"
      public   = false
    }
    "inventory-db" = {
      template = "large"
      public   = false
    }
  }

  source = "./modules/ionos/dcd-vm/buildingblock"

  datacenter_id = module.microservices_dc.datacenter_id
  vm_name       = each.key
  template      = each.value.template
  
  public_ip_required = each.value.public
  
  additional_data_disks = contains(["inventory-db"], each.key) ? [
    {
      name    = "database-storage"
      size_gb = 500
    }
  ] : []
}

# Outputs for service discovery
output "service_endpoints" {
  value = {
    for service, vm in module.services : service => {
      internal_ip = "private-ip-from-lan"
      public_ip   = vm.vm.public_ip_required ? vm.public_ips[0] : null
    }
  }
}
```

## Development Environment with Multiple Tiers

```hcl
module "dev_datacenter" {
  source = "./modules/ionos/dcd/buildingblock"

  datacenter_name = "dev-environment"
  datacenter_location = "de/fra"
  users = local.dev_team
}

# Frontend tier
module "frontend_vms" {
  for_each = toset(["frontend-01", "frontend-02"])

  source = "./modules/ionos/dcd-vm/buildingblock"

  datacenter_id = module.dev_datacenter.datacenter_id
  vm_name       = each.key
  template      = "small"
  
  public_ip_required = true
}

# Application tier
module "app_vms" {
  for_each = toset(["app-01", "app-02", "app-03"])

  source = "./modules/ionos/dcd-vm/buildingblock"

  datacenter_id = module.dev_datacenter.datacenter_id
  vm_name       = each.key
  template      = "medium"
  
  public_ip_required = false
}

# Database tier
module "database_vm" {
  source = "./modules/ionos/dcd-vm/buildingblock"

  datacenter_id = module.dev_datacenter.datacenter_id
  vm_name       = "database"
  template      = "large"
  
  additional_data_disks = [
    {
      name    = "db-data"
      size_gb = 500
    },
    {
      name    = "db-backups"
      size_gb = 1000
    }
  ]
  
  public_ip_required = false
}

# Outputs
output "frontend_ips" {
  value = {
    for name, vm in module.frontend_vms : name => vm.public_ips[0]
  }
}

output "database_id" {
  value = module.database_vm.server_id
}
```

## Deployment Workflow

### Initialize and Deploy

```bash
# 1. Set environment variables
export IONOS_TOKEN="your-token-here"

# 2. Initialize Terraform
terraform init

# 3. Plan deployment
terraform plan -out=tfplan

# 4. Apply the plan
terraform apply tfplan

# 5. View outputs
terraform output
```

### Access Your VMs

```bash
# Get frontend IPs
terraform output frontend_ips

# SSH into a VM
ssh ubuntu@<public-ip>

# Connect to internal services (from app tier)
ssh -i /path/to/key ubuntu@<app-internal-ip>
ssh -i /path/to/key ubuntu@<database-ip>
```

## Cost Optimization Strategy

### Development Environment
```hcl
module "dev_vm" {
  source = "./modules/ionos/dcd-vm/buildingblock"
  
  template      = "small"      # Cost: ~$15/month
  public_ip_required = true    # Keep for development
}
```

### Production Environment
```hcl
module "prod_vm" {
  source = "./modules/ionos/dcd-vm/buildingblock"
  
  template      = "large"      # Cost: ~$60/month
  public_ip_required = false   # Only where needed
}
```

## Backup and Disaster Recovery

```hcl
# Create VMs with backup capability
module "critical_service" {
  source = "./modules/ionos/dcd-vm/buildingblock"

  datacenter_id = module.dcd.datacenter_id
  vm_name       = "critical-app"
  template      = "large"
  
  # Data volume for backups
  additional_data_disks = [
    {
      name    = "backup"
      size_gb = 2000  # Large backup volume
    }
  ]
}

output "backup_instructions" {
  value = "Mount /mnt/backup and configure backup scripts"
}
```

## Next Steps

After deploying:

1. **Configure Network Security**: Set up firewall rules
2. **Install Software**: Deploy applications on VMs
3. **Enable Monitoring**: Set up performance monitoring
4. **Configure Backups**: Implement backup strategy
5. **Document Setup**: Record VM purposes and configs

For more details, see:
- `README.md` - Technical documentation
- `APP_TEAM_README.md` - User guide
- IONOS module: `modules/ionos/dcd/buildingblock/`
