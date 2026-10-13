resource "azurerm_resource_group" "backplane" {
  name     = var.name
  location = var.location
}

resource "azurerm_user_assigned_identity" "backplane" {
  name                = var.name
  location            = var.location
  resource_group_name = azurerm_resource_group.backplane.name
}

resource "azurerm_federated_identity_credential" "backplane" {
  for_each = { for i, s in var.workload_identity_federation.subjects : tostring(i) => s }

  name                      = "subject-${each.key}"
  user_assigned_identity_id = azurerm_user_assigned_identity.backplane.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = var.workload_identity_federation.issuer
  subject                   = each.value
}

resource "azurerm_role_definition" "backplane" {
  name        = "${var.name}-deploy"
  description = "Enables deployment of the ${var.name} IPAM pool building block"
  scope       = var.scope

  permissions {
    actions = [
      "Microsoft.Network/register/action",
      "Microsoft.Resources/subscriptions/providers/read",

      "Microsoft.Resources/subscriptions/resourceGroups/read",
      "Microsoft.Resources/subscriptions/resourceGroups/write",
      "Microsoft.Resources/subscriptions/resourceGroups/delete",

      "Microsoft.Network/networkManagers/read",
      "Microsoft.Network/networkManagers/write",
      "Microsoft.Network/networkManagers/delete",
      "Microsoft.Network/networkManagers/ipamPools/read",
      "Microsoft.Network/networkManagers/ipamPools/write",
      "Microsoft.Network/networkManagers/ipamPools/delete",

      "Microsoft.Management/managementGroups/read",
      "Microsoft.Resources/subscriptions/read",
    ]
  }
}

resource "azurerm_role_assignment" "backplane" {
  scope              = var.scope
  role_definition_id = azurerm_role_definition.backplane.role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.backplane.principal_id
}
