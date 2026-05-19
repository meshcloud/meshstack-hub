resource "azurerm_user_assigned_identity" "buildingblock" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_federated_identity_credential" "buildingblock" {
  for_each = { for i, s in var.workload_identity_federation.subjects : tostring(i) => s }

  name                = "subject-${each.key}"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.buildingblock.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.workload_identity_federation.issuer
  subject             = each.value
}

resource "azurerm_role_definition" "buildingblock_deploy" {
  name        = "${var.name}-deploy"
  description = "Enables deployment of the ${var.name} building block to subscriptions"
  scope       = var.scope
  permissions {
    actions = [
      # storage accounts
      "Microsoft.Storage/storageAccounts/write",
      "Microsoft.Storage/storageAccounts/read",
      "Microsoft.Storage/storageAccounts/delete",
      "Microsoft.Storage/storageAccounts/managementPolicies/write",
      "Microsoft.Storage/storageAccounts/managementPolicies/read",
      "Microsoft.Storage/storageAccounts/managementPolicies/delete",
      "Microsoft.Storage/storageAccounts/objectReplicationPolicies/write",
      "Microsoft.Storage/storageAccounts/objectReplicationPolicies/read",
      "Microsoft.Storage/storageAccounts/objectReplicationPolicies/delete",
      "Microsoft.Storage/storageAccounts/listKeys/action",

      # resource groups
      "Microsoft.Resources/subscriptions/resourcegroups/read",
      "Microsoft.Resources/subscriptions/resourcegroups/write",
      "Microsoft.Resources/subscriptions/resourcegroups/delete",

      # sub-resources
      "Microsoft.Storage/storageAccounts/blobServices/read",
      "Microsoft.Storage/storageAccounts/blobServices/write",
      "Microsoft.Storage/storageAccounts/fileServices/read",
      "Microsoft.Storage/storageAccounts/fileServices/write",
      "Microsoft.Storage/storageAccounts/queueServices/read",
      "Microsoft.Storage/storageAccounts/queueServices/write",
      "Microsoft.Storage/storageAccounts/tableServices/read",
      "Microsoft.Storage/storageAccounts/tableServices/write",
    ]
  }
}

resource "azurerm_role_assignment" "buildingblock" {
  scope              = var.scope
  role_definition_id = azurerm_role_definition.buildingblock_deploy.role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.buildingblock.principal_id
}
