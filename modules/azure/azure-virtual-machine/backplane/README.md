# Azure Virtual Machine Building Block - Backplane

This directory contains the "backplane" configuration for the Azure Virtual Machine Building Block. The backplane sets up the necessary permissions and service principals required to deploy Virtual Machines in Azure subscriptions.

## Overview

The backplane creates:
- Custom Azure RBAC role definition with VM deployment permissions
- Optional service principal for automated deployments
- Role assignments for the service principal or existing principals
- Support for workload identity federation or application passwords

## Required Permissions

The role definition grants the following permissions:

### Virtual Machines
- Read, write, and delete virtual machines
- Manage VM disks

### Networking
- Create and manage network interfaces
- Create and manage public IPs (optional)
- Create and manage network security groups
- Read and join virtual networks and subnets

### Resource Management
- Create, read, and delete resource groups
- Assign managed identities

## Usage

```hcl
module "vm_backplane" {
  source = "./backplane"

  name  = "azure-vm"
  scope = "/subscriptions/your-subscription-id"

  # Option 1: Use existing service principal
  existing_principal_ids = ["existing-sp-object-id"]

  # Option 2: Create new service principal with workload identity federation
  create_service_principal_name = "vm-deployer"
  workload_identity_federation = {
    issuer  = "https://token.actions.githubusercontent.com"
    subject = "repo:your-org/your-repo:ref:refs/heads/main"
  }

  # Option 3: Create new service principal with password
  create_service_principal_name = "vm-deployer"
  # Omit workload_identity_federation to use password authentication
}
```

## Security Considerations

- The role definition follows the principle of least privilege
- Service principals should use workload identity federation when possible
- Passwords are marked as sensitive and not exposed in outputs
- Review the permissions before deploying to production environments

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_azuread"></a> [azuread](#requirement\_azuread) | ~>3.6.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~>4.50.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azuread_application.buildingblock_deploy](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application) | resource |
| [azuread_application_federated_identity_credential.buildingblock_deploy](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application_federated_identity_credential) | resource |
| [azuread_application_password.buildingblock_deploy](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application_password) | resource |
| [azuread_service_principal.buildingblock_deploy](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/service_principal) | resource |
| [azurerm_role_assignment.created_principal](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.existing_principals](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_definition.buildingblock_deploy](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_definition) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_create_service_principal_name"></a> [create\_service\_principal\_name](#input\_create\_service\_principal\_name) | name of a service principal to create and grant permissions to deploy the building block | `string` | `null` | no |
| <a name="input_existing_principal_ids"></a> [existing\_principal\_ids](#input\_existing\_principal\_ids) | set of existing principal ids that will be granted permissions to deploy the building block | `set(string)` | `[]` | no |
| <a name="input_name"></a> [name](#input\_name) | name of the building block, used for naming resources | `string` | n/a | yes |
| <a name="input_scope"></a> [scope](#input\_scope) | Scope where the building block should be deployable, typically the parent of all Landing Zones. | `string` | n/a | yes |
| <a name="input_workload_identity_federation"></a> [workload\_identity\_federation](#input\_workload\_identity\_federation) | Configuration for workload identity federation. If not provided, an application password will be created instead. | <pre>object({<br>    issuer  = string<br>    subject = string<br>  })</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_application_password"></a> [application\_password](#output\_application\_password) | Information about the created application password (excludes the actual password value for security). |
| <a name="output_created_application"></a> [created\_application](#output\_created\_application) | Information about the created Azure AD application. |
| <a name="output_created_service_principal"></a> [created\_service\_principal](#output\_created\_service\_principal) | Information about the created service principal. |
| <a name="output_documentation_md"></a> [documentation\_md](#output\_documentation\_md) | Markdown documentation with information about the Azure Virtual Machine Building Block backplane |
| <a name="output_role_assignment_ids"></a> [role\_assignment\_ids](#output\_role\_assignment\_ids) | The IDs of the role assignments for all service principals. |
| <a name="output_role_assignment_principal_ids"></a> [role\_assignment\_principal\_ids](#output\_role\_assignment\_principal\_ids) | The principal IDs of all service principals that have been assigned the role. |
| <a name="output_role_definition_id"></a> [role\_definition\_id](#output\_role\_definition\_id) | The ID of the role definition that enables deployment of the building block to subscriptions. |
| <a name="output_role_definition_name"></a> [role\_definition\_name](#output\_role\_definition\_name) | The name of the role definition that enables deployment of the building block to subscriptions. |
| <a name="output_scope"></a> [scope](#output\_scope) | The scope where the role definition and role assignments are applied. |
| <a name="output_workload_identity_federation"></a> [workload\_identity\_federation](#output\_workload\_identity\_federation) | Information about the created workload identity federation credential. |
<!-- END_TF_DOCS -->