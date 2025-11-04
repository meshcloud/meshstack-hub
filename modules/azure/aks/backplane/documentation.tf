output "documentation_md" {
  value       = <<EOF
# AKS Building Block

The Azure AKS Building Block configures a AKS (Kubernetes Service) cluster in the Azure cloud, which can be used to deploy and run containerized applications.

## Automation

We automate the deployment of a AKS Building Block using the common [Azure Building Blocks Automation Infrastructure](../automation.md).
In order to deploy this building block, this infrastructure receives the following roles.

| Role Name | Description | Permissions |
|-----------|-------------|-------------|
| `${azurerm_role_definition.buildingblock_deploy.name}` | ${azurerm_role_definition.buildingblock_deploy.description} | ${join("<br>", formatlist("- `%s`", azurerm_role_definition.buildingblock_deploy.permissions[0].actions))} |

EOF
  description = "Markdown documentation with information about the AKS Building Block building block backplane"
}
