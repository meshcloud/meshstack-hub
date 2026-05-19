# Service Principal Creation
resource "azuread_application" "buildingblock_deploy" {
  count = var.create_service_principal_name != null ? 1 : 0

  display_name = var.create_service_principal_name
}

resource "azuread_service_principal" "buildingblock_deploy" {
  count = var.create_service_principal_name != null ? 1 : 0

  client_id                    = azuread_application.buildingblock_deploy[0].client_id
  app_role_assignment_required = false
}


# Create federated identity credentials (one per subject)
# Use a map with static numeric string keys so that for_each keys are known at plan time,
# even when subject values contain apply-time unknowns (e.g. building block definition UUIDs).
resource "azuread_application_federated_identity_credential" "buildingblock_deploy" {
  for_each = var.create_service_principal_name != null && var.workload_identity_federation != null ? {
    for i, s in var.workload_identity_federation.subjects : tostring(i) => s
  } : {}

  application_id = azuread_application.buildingblock_deploy[0].id
  display_name   = "subject-${each.key}"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = var.workload_identity_federation.issuer
  subject        = each.value
}
# Create application password (when not using workload identity federation)
resource "azuread_application_password" "buildingblock_deploy" {
  count = var.create_service_principal_name != null && var.workload_identity_federation == null ? 1 : 0

  application_id = azuread_application.buildingblock_deploy[0].id
  display_name   = "${var.create_service_principal_name}-password"
}

# Role Definition
resource "azurerm_role_definition" "buildingblock_deploy" {
  name        = "${var.name}-deploy"
  description = "Enables deployment of the ${var.name} building block to subscriptions"
  scope       = var.scope
  permissions {
    actions = [
      # resource manager
      "*/register/action",
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

# Role Assignments for existing principals
resource "azurerm_role_assignment" "existing_principals" {
  for_each = var.existing_principal_ids

  role_definition_id = azurerm_role_definition.buildingblock_deploy.role_definition_resource_id
  principal_id       = each.value
  scope              = var.scope
}

# Role Assignment for created service principal
resource "azurerm_role_assignment" "created_principal" {
  count = var.create_service_principal_name != null ? 1 : 0

  role_definition_id = azurerm_role_definition.buildingblock_deploy.role_definition_resource_id
  principal_id       = azuread_service_principal.buildingblock_deploy[0].object_id
  scope              = var.scope
}
