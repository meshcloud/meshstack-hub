output "documentation_md" {
  value       = <<EOF
# Service Principal Building Block

The Service Principal Building Block creates Azure AD applications and service principals with role assignments for your subscriptions.

## Automation

We automate the deployment of the Service Principal Building Block using the common [Azure Building Blocks Automation Infrastructure](../automation.md).
In order to deploy this building block, this infrastructure receives the following roles and permissions.

### Azure RBAC Role

| Role Name | Description | Permissions |
|-----------|-------------|-------------|
| `${azurerm_role_definition.buildingblock_deploy.name}` | ${azurerm_role_definition.buildingblock_deploy.description} | ${join("<br>", formatlist("- `%s`", azurerm_role_definition.buildingblock_deploy.permissions[0].actions))} |

### Microsoft Graph API Permissions

The service principal also requires the following Microsoft Graph API application permissions:

| Permission | Description |
|------------|-------------|
| `Application.ReadWrite.OwnedBy` | Allows the app to create other applications and service principals, and fully manage those applications (read, update, delete). It cannot update any applications that it is not an owner of. |

> **Note:** The `Application.ReadWrite.OwnedBy` permission requires admin consent in Azure AD.

EOF
  description = "Markdown documentation with information about the Service Principal Building Block backplane"
}
