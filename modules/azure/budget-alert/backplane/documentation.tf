output "documentation_md" {
  value       = <<EOF
# Subscription Budget Alert

The Budget Alert Building block configures a simple monthly budget alert for subscriptions.
We highly recommend (and for some landing zones enforce) that application teams set up an alert as a simple
mechanism to prevent unintentional cost overruns.

We encourage application teams to deploy additional alerts with fine-grained notification rules according to the
specific needs of their application and infrastructure.

# 💰 Budget Alert Building Block Backplane

This module automates the deployment of a Budget Alert building block within Azure. It utilizes the common [Azure Building Blocks Automation Infrastructure](./azure-buildingblocks-automation)


## 🛠️ Role Definition

| Name | ID |
| --- | --- |
| ${azurerm_role_definition.buildingblock_deploy.name} | ${azurerm_role_definition.buildingblock_deploy.id} |

## 📝 Role Assignments

| Principal ID |
| --- |
| ${join("\n", concat([for assignment in azurerm_role_assignment.existing_principals : assignment.principal_id], var.create_service_principal_name != null ? [azurerm_role_assignment.created_principal[0].principal_id] : []))} |

## 🎯 Scope

- **Scope**: `${var.scope}`

EOF
  description = "Markdown documentation with information about the Budget Alert building block backplane"
}

