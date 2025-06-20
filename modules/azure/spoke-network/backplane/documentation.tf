output "documentation_md" {
  value = <<EOF
# Connectivity

The Connectivity building block deploys a managed spoke network that's connected to Likvid Bank's central network hub.
This enables on-premise connectivity via the central hub.

## Automation

We automates the deployment of this building block using the common [Azure Building Blocks Automation Infrastructure](../automation.md).
In order to deploy this building block, this infrastructure receives the following roles.

| Role Name | Description | Permissions |
|-----------|-------------|-------------|
| `${azurerm_role_definition.buildingblock_deploy_hub.name}` | On the central network hub: ${azurerm_role_definition.buildingblock_deploy_hub.description} | ${join("<br>", formatlist("- `%s`", azurerm_role_definition.buildingblock_deploy_hub.permissions[0].actions))} |
| `Owner` | On the resource group hosting the spoke network in the target subscription. | `*` |

EOF
}

