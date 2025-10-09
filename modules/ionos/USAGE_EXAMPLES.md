# IONOS Module Usage Examples

This document provides complete examples of how to use the IONOS modules together.

## Architecture Overview

The IONOS modules are split into two components:

1. **User Management Module**: Creates and manages IONOS users (deploy once)
2. **DCD Module**: Creates datacenter environments and assigns existing users

## Complete Example

### Step 1: Deploy User Management (Once per IONOS Account)

```hcl
# main.tf
module "ionos_users" {
  source = "./modules/ionos/user-management/buildingblock"

  # Authentication
  ionos_token = var.ionos_token

  # User configuration  
  default_user_password = var.default_user_password
  force_sec_auth       = true

  # Users from authoritative system
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
    },
    {
      meshIdentifier = "reader-001"
      username       = "bob.wilson"
      firstName      = "Bob"
      lastName       = "Wilson"
      email          = "bob.wilson@company.com"
      euid           = "bob.wilson"
      roles          = ["reader"]
    }
  ]
}
```

### Step 2: Deploy DCD Environment (Multiple environments possible)

```hcl
# dcd-development.tf
module "dev_datacenter" {
  source = "./modules/ionos/dcd/buildingblock"
  
  # Datacenter configuration
  datacenter_name        = "development-env"
  datacenter_location    = "de/fra"
  datacenter_description = "Development environment"
  
  # Authentication
  ionos_token = var.ionos_token
  
  # Users (same list as user management)
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

# dcd-production.tf
module "prod_datacenter" {
  source = "./modules/ionos/dcd/buildingblock"
  
  # Datacenter configuration
  datacenter_name        = "production-env"
  datacenter_location    = "de/fra"
  datacenter_description = "Production environment"
  
  # Authentication
  ionos_token = var.ionos_token
  
  # Users (different subset for production)
  users = [
    {
      meshIdentifier = "admin-001"
      username       = "jane.smith"
      firstName      = "Jane"
      lastName       = "Smith"
      email          = "jane.smith@company.com"
      euid           = "jane.smith"
      roles          = ["admin"]
    },
    {
      meshIdentifier = "reader-001"
      username       = "bob.wilson"
      firstName      = "Bob"
      lastName       = "Wilson"
      email          = "bob.wilson@company.com"
      euid           = "bob.wilson"
      roles          = ["reader"]
    }
  ]
}
```

### Variables Configuration

```hcl
# variables.tf
variable "ionos_token" {
  description = "IONOS API token"
  type        = string
  sensitive   = true
}

variable "default_user_password" {
  description = "Default password for IONOS users"
  type        = string
  sensitive   = true
}
```

### Terraform Configuration

```hcl
# terraform.tfvars (example - use your own values)
ionos_token           = "your-ionos-api-token"
default_user_password = "ChangeMe123!"
```

## Deployment Sequence

### Initial Deployment
```bash
# 1. Deploy user management first
terraform apply -target=module.ionos_users

# 2. Deploy DCD environments
terraform apply -target=module.dev_datacenter
terraform apply -target=module.prod_datacenter
```

### Safe Environment Destruction
```bash
# You can safely destroy DCD environments without affecting users
terraform destroy -target=module.dev_datacenter

# Users persist and can be used by other environments
terraform apply -target=module.dev_datacenter  # Recreate safely
```

## Benefits of This Architecture

✅ **User Persistence**: Users survive environment changes  
✅ **Flexible Environments**: Different user sets per datacenter  
✅ **Safe Operations**: Destroy/recreate environments without user impact  
✅ **Cost Effective**: Users are created once, used by multiple environments  
✅ **Role Separation**: Clear separation between user management and infrastructure

## Common Scenarios

### Scenario 1: New Team Member
1. Add user to the `ionos_users` module
2. Apply user management: `terraform apply -target=module.ionos_users`
3. Add user to relevant DCD modules
4. Apply DCD changes: `terraform apply -target=module.dev_datacenter`

### Scenario 2: Environment Refresh
1. Destroy environment: `terraform destroy -target=module.dev_datacenter`
2. Recreate environment: `terraform apply -target=module.dev_datacenter`
3. Users automatically get reassigned to new environment

### Scenario 3: User Role Change
1. Update user roles in both modules
2. Apply changes - users get moved to appropriate groups automatically