data "azurerm_subscription" "current" {
}

resource "azuread_application" "buildingblock_deploy" {
  count = var.create_service_principal_name != null ? 1 : 0

  display_name = "${var.name}-${var.create_service_principal_name}"
}

resource "azuread_service_principal" "buildingblock_deploy" {
  count = var.create_service_principal_name != null ? 1 : 0

  client_id                    = azuread_application.buildingblock_deploy[0].client_id
  app_role_assignment_required = false
}

resource "azuread_application_federated_identity_credential" "buildingblock_deploy" {
  count = var.create_service_principal_name != null && var.workload_identity_federation != null ? 1 : 0

  application_id = azuread_application.buildingblock_deploy[0].id
  display_name   = var.create_service_principal_name
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = var.workload_identity_federation.issuer
  subject        = var.workload_identity_federation.subject
}

resource "azuread_application_password" "buildingblock_deploy" {
  count = var.create_service_principal_name != null && var.workload_identity_federation == null ? 1 : 0

  application_id = azuread_application.buildingblock_deploy[0].id
  display_name   = "${var.create_service_principal_name}-password"
}

resource "azurerm_role_definition" "buildingblock_deploy" {
  name        = "${var.name}-deploy"
  description = "Enables deployment of the ${var.name} building block to subscriptions"
  scope       = var.scope

  permissions {
    actions = [
      # Register resource providers in Azure Resource Manager
      "*/register/action",

      # Budget
      "Microsoft.Consumption/budgets/*",

      # Resource Groups
      "Microsoft.Resources/subscriptions/resourceGroups/read",
      "Microsoft.Resources/subscriptions/providers/read",
    ]
  }
}

resource "azurerm_role_assignment" "existing_principals" {
  for_each = var.existing_principal_ids

  role_definition_id = azurerm_role_definition.buildingblock_deploy.role_definition_resource_id
  principal_id       = each.value
  scope              = var.scope
}

resource "azurerm_role_assignment" "created_principal" {
  count = var.create_service_principal_name != null ? 1 : 0

  role_definition_id = azurerm_role_definition.buildingblock_deploy.role_definition_resource_id
  principal_id       = azuread_service_principal.buildingblock_deploy[0].object_id
  scope              = var.scope
}

resource "azuread_directory_role" "directory_readers" {
  display_name = "Directory Readers"
}

resource "azuread_directory_role_assignment" "directory_readers_existing" {
  for_each            = var.existing_principal_ids
  role_id             = azuread_directory_role.directory_readers.template_id
  principal_object_id = each.value
}

resource "azuread_directory_role_assignment" "directory_readers_created" {
  count               = var.create_service_principal_name != null ? 1 : 0
  role_id             = azuread_directory_role.directory_readers.template_id
  principal_object_id = azuread_service_principal.buildingblock_deploy[0].object_id
}
