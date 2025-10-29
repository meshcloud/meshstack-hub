data "azurerm_client_config" "current" {}

data "azurerm_subscription" "target" {
  subscription_id = var.azure_subscription_id
}

resource "azuread_application" "main" {
  display_name = var.display_name
  description  = var.description
  owners       = length(var.owners) > 0 ? var.owners : [data.azurerm_client_config.current.object_id]
}

resource "azuread_service_principal" "main" {
  client_id = azuread_application.main.client_id
  owners    = length(var.owners) > 0 ? var.owners : [data.azurerm_client_config.current.object_id]
}

resource "time_rotating" "secret_rotation" {
  rotation_days = var.secret_rotation_days
}

resource "azuread_application_password" "main" {
  application_id = azuread_application.main.id
  display_name   = "Terraform-managed secret"

  rotate_when_changed = {
    rotation = time_rotating.secret_rotation.id
  }
}

resource "azurerm_role_assignment" "main" {
  scope                = data.azurerm_subscription.target.id
  role_definition_name = var.azure_role
  principal_id         = azuread_service_principal.main.object_id
}
