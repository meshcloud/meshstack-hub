# note: this building block is expected to be executed with pre configured output by the "backplane" module in the
# parent dir, this needs to provided in the BB execution enviornment

data "azurerm_subscription" "current" {}
data "azuread_client_config" "current" {}

# note: it's important that all other azure resources transitively depend on this role assignment or else they will fail
resource "azurerm_role_assignment" "starterkit_deploy" {
  # since the role is defined on MG level, we need to prefix the subscription id here to make terraform happy and not plan replacements
  # see https://github.com/hashicorp/terraform-provider-azurerm/issues/19847#issuecomment-1407262429
  role_definition_id = "${data.azurerm_subscription.current.id}/providers/Microsoft.Authorization/roleDefinitions/${var.deploy_role_definition_id}"

  description  = "Grant permissions to deploy a starterkit building block."
  principal_id = data.azuread_client_config.current.object_id
  scope        = data.azurerm_subscription.current.id
}
