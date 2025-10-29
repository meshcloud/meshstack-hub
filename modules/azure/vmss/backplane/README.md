# Azure Virtual Machine Scale Set Building Block - Backplane

This directory contains the "backplane" configuration for the Azure Virtual Machine Scale Set Building Block. The backplane sets up the necessary permissions and service principals required to deploy VMSS in Azure subscriptions.

## Overview

The backplane creates:
- Custom Azure RBAC role definition with VMSS deployment permissions
- Optional service principal for automated deployments
- Role assignments for the service principal or existing principals
- Support for workload identity federation or application passwords

## Required Permissions

The role definition grants the following permissions:

### Virtual Machine Scale Sets
- Read, write, and delete VMSS and instances
- Manage VM disks
- Control VMSS operations (scale, upgrade, etc.)

### Load Balancing
- Create and manage Azure Load Balancers
- Configure backend pools and health probes
- Manage load balancing rules

### Networking
- Create and manage network interfaces
- Create and manage public IPs
- Create and manage network security groups
- Read and join virtual networks and subnets

### Autoscaling
- Create and manage autoscale settings
- Configure autoscale rules and metrics
- Read monitoring data

### Resource Management
- Create, read, and delete resource groups
- Assign managed identities

## Usage

```hcl
module "vmss_backplane" {
  source = "./backplane"

  name  = "azure-vmss"
  scope = "/subscriptions/your-subscription-id"

  # Option 1: Use existing service principal
  existing_principal_ids = {
    "existing-sp" = "existing-sp-object-id"
  }

  # Option 2: Create new service principal with workload identity federation
  create_service_principal_name = "vmss-deployer"
  workload_identity_federation = {
    issuer  = "https://token.actions.githubusercontent.com"
    subject = "repo:your-org/your-repo:ref:refs/heads/main"
  }

  # Option 3: Create new service principal with password
  create_service_principal_name = "vmss-deployer"
}
```

## Security Considerations

- The role definition follows the principle of least privilege
- Service principals should use workload identity federation when possible
- Passwords are marked as sensitive and not exposed in outputs
- Review the permissions before deploying to production environments
- VMSS permissions include autoscaling and load balancer management
