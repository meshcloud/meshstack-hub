output "documentation_md" {
  value       = <<EOF
# Container Registry Building Block

The Container Registry Building Block configures an Azure Container Registry (ACR) with optional private networking for your subscriptions.

## Automation

We automate the deployment of a Container Registry Building Block using the common [Azure Building Blocks Automation Infrastructure](../automation.md).
In order to deploy this building block, this infrastructure receives the following roles.

| Role Name | Description | Permissions |
|-----------|-------------|-------------|
| `${azurerm_role_definition.buildingblock_deploy.name}` | ${azurerm_role_definition.buildingblock_deploy.description} | ${join("<br>", formatlist("- `%s`", azurerm_role_definition.buildingblock_deploy.permissions[0].actions))} |
| `${azurerm_role_definition.buildingblock_deploy_hub.name}` | ${azurerm_role_definition.buildingblock_deploy_hub.description} | ${join("<br>", formatlist("- `%s`", azurerm_role_definition.buildingblock_deploy_hub.permissions[0].actions))} |

EOF
  description = "Markdown documentation with information about the Container Registry Building Block backplane"
}
