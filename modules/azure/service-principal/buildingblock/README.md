---
name: Azure Service Principal
supportedPlatforms:
  - azure
description: Creates an Azure AD application registration and service principal with role assignment for automated access to Azure resources
category: security
---

# Azure Service Principal Building Block

Creates and manages an Azure AD application registration, service principal, and role assignment for automated access to Azure subscriptions.

This documentation is intended as a reference for cloud foundation or platform engineers using this module.

## Prerequisites

- Azure subscription with appropriate permissions
- Permissions to create Azure AD applications and service principals
- Permissions to assign roles at subscription scope

## Features

- Creates Azure AD application registration
- Creates service principal linked to the application
- Generates client secret with configurable expiration
- Assigns Azure RBAC role at subscription scope
- Automatic secret rotation based on time interval
- Supports Owner, Contributor, and Reader roles

## Usage

### Basic Service Principal with Contributor Role

```hcl
module "service_principal" {
  source = "./buildingblock"

  display_name          = "my-app-service-principal"
  description           = "Service principal for CI/CD pipeline"
  azure_subscription_id = "12345678-1234-1234-1234-123456789012"
  azure_role            = "Contributor"
}

output "client_id" {
  value = module.service_principal.service_principal_id
}

output "client_secret" {
  value     = module.service_principal.client_secret
  sensitive = true
}

output "tenant_id" {
  value = module.service_principal.tenant_id
}
```

### Service Principal with Reader Role

```hcl
module "readonly_sp" {
  source = "./buildingblock"

  display_name          = "monitoring-service-principal"
  description           = "Read-only access for monitoring tools"
  azure_subscription_id = "12345678-1234-1234-1234-123456789012"
  azure_role            = "Reader"
}
```

### Service Principal with Custom Secret Rotation

```hcl
module "long_lived_sp" {
  source = "./buildingblock"

  display_name          = "long-lived-service-principal"
  azure_subscription_id = "12345678-1234-1234-1234-123456789012"
  azure_role            = "Contributor"
  secret_rotation_days  = 180
}
```

### Service Principal with Custom Owners

```hcl
data "azuread_user" "admin" {
  user_principal_name = "admin@example.com"
}

module "managed_sp" {
  source = "./buildingblock"

  display_name          = "team-managed-service-principal"
  azure_subscription_id = "12345678-1234-1234-1234-123456789012"
  azure_role            = "Contributor"
  owners                = [data.azuread_user.admin.object_id]
}
```

## Role Options

- **Owner**: Full access including role assignments (use sparingly)
- **Contributor**: Full management access except role assignments (recommended)
- **Reader**: Read-only access to resources

## Secret Management

The module automatically manages service principal secrets with:
- Configurable expiration period (30-730 days)
- Automatic rotation based on time_rotating resource
- Default rotation period: 90 days

**Note**: After secret rotation, you must retrieve the new secret from Terraform state or outputs.

## Integration with Azure DevOps Service Connection

```hcl
module "devops_service_principal" {
  source = "./buildingblock"

  display_name          = "azuredevops-deployment-sp"
  description           = "Service principal for Azure DevOps pipelines"
  azure_subscription_id = var.subscription_id
  azure_role            = "Contributor"
}

module "azuredevops_service_connection" {
  source = "../../azuredevops/service-connection-subscription/buildingblock"

  azure_devops_organization_url = var.org_url
  key_vault_name                = var.key_vault_name
  resource_group_name           = var.resource_group_name

  project_id              = var.project_id
  service_connection_name = "Azure-Production"
  azure_subscription_id   = var.subscription_id
  service_principal_id    = module.devops_service_principal.service_principal_id
  service_principal_key   = module.devops_service_principal.client_secret
  azure_tenant_id         = module.devops_service_principal.tenant_id
}
```

## Outputs

- `application_id` - Application (client) ID
- `application_object_id` - Application object ID
- `service_principal_id` - Service principal client ID (same as application_id)
- `service_principal_object_id` - Service principal object ID
- `client_secret` - Client secret (sensitive)
- `tenant_id` - Azure AD tenant ID
- `subscription_id` - Subscription ID where role was assigned
- `azure_role` - Assigned Azure role
- `secret_expiration_date` - Secret expiration date

## Security Considerations

- Store client secrets securely (Key Vault, secret management system)
- Use least privilege principle - prefer Reader or Contributor over Owner
- Monitor secret expiration dates
- Rotate secrets regularly
- Limit application owners to trusted administrators
- Review role assignments periodically

## Limitations

- Role assignment is at subscription scope only
- Only supports built-in Owner, Contributor, and Reader roles
- Changing display_name requires recreation of application
- Secret rotation requires Terraform apply to take effect

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_azuread"></a> [azuread](#requirement\_azuread) | ~> 2.53.1 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 3.116.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | ~> 0.11.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azuread_application.main](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application) | resource |
| [azuread_application_password.main](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application_password) | resource |
| [azuread_service_principal.main](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/service_principal) | resource |
| [azurerm_role_assignment.main](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [time_rotating.secret_rotation](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/rotating) | resource |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |
| [azurerm_subscription.target](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subscription) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_azure_role"></a> [azure\_role](#input\_azure\_role) | Azure RBAC role to assign to the service principal on the subscription | `string` | `"Contributor"` | no |
| <a name="input_azure_subscription_id"></a> [azure\_subscription\_id](#input\_azure\_subscription\_id) | Azure Subscription ID where role assignments will be created | `string` | n/a | yes |
| <a name="input_description"></a> [description](#input\_description) | Description for the Azure AD application | `string` | `"Service principal managed by Terraform"` | no |
| <a name="input_display_name"></a> [display\_name](#input\_display\_name) | Display name for the Azure AD application and service principal | `string` | n/a | yes |
| <a name="input_owners"></a> [owners](#input\_owners) | List of object IDs to set as owners of the application (defaults to current user) | `list(string)` | `[]` | no |
| <a name="input_secret_rotation_days"></a> [secret\_rotation\_days](#input\_secret\_rotation\_days) | Number of days before the service principal secret expires | `number` | `90` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_application_id"></a> [application\_id](#output\_application\_id) | Application (client) ID of the Azure AD application |
| <a name="output_application_object_id"></a> [application\_object\_id](#output\_application\_object\_id) | Object ID of the Azure AD application |
| <a name="output_azure_role"></a> [azure\_role](#output\_azure\_role) | Azure role assigned to the service principal |
| <a name="output_client_secret"></a> [client\_secret](#output\_client\_secret) | Client secret for the service principal |
| <a name="output_secret_expiration_date"></a> [secret\_expiration\_date](#output\_secret\_expiration\_date) | Date when the service principal secret will expire |
| <a name="output_service_principal_id"></a> [service\_principal\_id](#output\_service\_principal\_id) | Client ID of the service principal (same as application_id) |
| <a name="output_service_principal_object_id"></a> [service\_principal\_object\_id](#output\_service\_principal\_object\_id) | Object ID of the service principal |
| <a name="output_subscription_id"></a> [subscription\_id](#output\_subscription\_id) | Azure Subscription ID where role assignment was created |
| <a name="output_tenant_id"></a> [tenant\_id](#output\_tenant\_id) | Azure AD Tenant ID |
<!-- END_TF_DOCS -->
