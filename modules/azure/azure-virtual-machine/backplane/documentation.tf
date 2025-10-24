output "documentation_md" {
  value       = <<EOF
# Azure Virtual Machine Building Block

The Azure Virtual Machine Building Block configures virtual machines for your subscriptions with support for both Linux and Windows operating systems.

## Automation

We automate the deployment of an Azure Virtual Machine Building Block using the common [Azure Building Blocks Automation Infrastructure](../automation.md).
In order to deploy this building block, this infrastructure receives the following roles.

| Role Name | Description | Permissions |
|-----------|-------------|-------------|
| `${azurerm_role_definition.buildingblock_deploy.name}` | ${azurerm_role_definition.buildingblock_deploy.description} | ${join("<br>", formatlist("- `%s`", azurerm_role_definition.buildingblock_deploy.permissions[0].actions))} |

EOF
  description = "Markdown documentation with information about the Azure Virtual Machine Building Block backplane"
}
