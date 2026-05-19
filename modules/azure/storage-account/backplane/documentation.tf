output "documentation_md" {
  value       = <<EOF
# Storage Account Building Block

The Storage Account Building Block configures a storage account for your subscriptions.

## Automation

We automate the deployment of a Storage Account Building Block using a User-Assigned Managed
Identity (UAMI) with Workload Identity Federation. The UAMI receives the following roles.

| Role Name | Description | Permissions |
|-----------|-------------|-------------|
| `${azurerm_role_definition.buildingblock_deploy.name}` | ${azurerm_role_definition.buildingblock_deploy.description} | ${join("<br>", formatlist("- `%s`", azurerm_role_definition.buildingblock_deploy.permissions[0].actions))} |

EOF
  description = "Markdown documentation with information about the Storage Account Building Block building block backplane"
}

