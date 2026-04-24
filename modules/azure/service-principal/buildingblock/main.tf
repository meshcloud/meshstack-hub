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
  count = var.create_client_secret ? 1 : 0

  rotation_days = var.secret_rotation_days
}

resource "azuread_application_password" "main" {
  count = var.create_client_secret ? 1 : 0

  application_id = azuread_application.main.id
  display_name   = "Terraform-managed secret"

  rotate_when_changed = {
    rotation = time_rotating.secret_rotation[0].id
  }
}

# -----------------------------------------------------------------------------
# Custom Role Definition (optional)
# Created only when var.custom_role is specified
# -----------------------------------------------------------------------------

resource "azurerm_role_definition" "custom" {
  count = var.custom_role != null ? 1 : 0

  name        = var.custom_role.name
  scope       = data.azurerm_subscription.target.id
  description = var.custom_role.description

  permissions {
    actions          = var.custom_role.actions
    not_actions      = var.custom_role.not_actions
    data_actions     = var.custom_role.data_actions
    not_data_actions = var.custom_role.not_data_actions
  }

  assignable_scopes = [data.azurerm_subscription.target.id]
}

# -----------------------------------------------------------------------------
# Role Assignment
# Uses custom role if defined, otherwise uses built-in role
# -----------------------------------------------------------------------------

resource "azurerm_role_assignment" "main" {
  count = var.custom_role != null || var.azure_role != null ? 1 : 0

  scope                = data.azurerm_subscription.target.id
  role_definition_id   = var.custom_role != null ? azurerm_role_definition.custom[0].role_definition_resource_id : null
  role_definition_name = var.custom_role == null ? var.azure_role : null
  principal_id         = azuread_service_principal.main.object_id
}
