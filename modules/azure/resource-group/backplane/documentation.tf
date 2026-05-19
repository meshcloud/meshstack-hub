output "documentation_md" {
  value       = <<EOF
# Azure Resource Group Building Block

The Resource Group Building Block creates an empty Azure Resource Group for a meshStack project.
The resource group name is automatically generated following the schema `rg-<workspaceId>-<projectId>`,
ensuring consistent naming across all landing zones.

# Azure Resource Group Building Block Backplane

This module automates the IAM setup required for the Resource Group building block within Azure.

## Role Definition

| Name | ID |
| --- | --- |
| ${azurerm_role_definition.buildingblock_deploy.name} | ${azurerm_role_definition.buildingblock_deploy.id} |

## Role Assignments

| Principal ID |
| --- |
| ${join("\n", concat([for assignment in azurerm_role_assignment.existing_principals : assignment.principal_id], var.create_service_principal_name != null ? [azurerm_role_assignment.created_principal[0].principal_id] : []))} |

## Scope

- **Scope**: `${var.scope}`

EOF
  description = "Markdown documentation with information about the Resource Group building block backplane."
}
