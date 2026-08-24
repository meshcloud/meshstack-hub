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

#
# Spoke deploy role — grants the automation identity everything it needs on the
# subscriptions/management group that hosts the spoke landing zones: manage the
# spoke resource group and vnet, hand out ownership on the spoke RG, and create
# the spoke side of the vnet peering.
#
resource "azurerm_role_definition" "backplane" {
  name        = "${var.name}-deploy"
  description = "Enables deployment of the ${var.name} spoke network building block to landing zone subscriptions"
  scope       = var.scope

  permissions {
    actions = [
      # Register resource providers in Azure Resource Manager
      "*/register/action",
      "Microsoft.Resources/subscriptions/providers/read",

      # Spoke resource group
      "Microsoft.Resources/subscriptions/resourceGroups/read",
      "Microsoft.Resources/subscriptions/resourceGroups/write",
      "Microsoft.Resources/subscriptions/resourceGroups/delete",

      # Spoke virtual network + subnets + peering
      "Microsoft.Network/virtualNetworks/read",
      "Microsoft.Network/virtualNetworks/write",
      "Microsoft.Network/virtualNetworks/delete",
      "Microsoft.Network/virtualNetworks/subnets/read",
      "Microsoft.Network/virtualNetworks/subnets/write",
      "Microsoft.Network/virtualNetworks/subnets/delete",
      "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/read",
      "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/write",
      "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/delete",
      "Microsoft.Network/virtualNetworks/peer/action",

      # The building block hands ownership of the spoke resource group to the tenant
      "Microsoft.Authorization/roleAssignments/read",
      "Microsoft.Authorization/roleAssignments/write",
      "Microsoft.Authorization/roleAssignments/delete",
    ]
  }
}

#
# Hub peering role — the spoke network building block peers *both* sides of the
# connection, so the same identity also needs rights where the hub lives: read
# the hub vnet/resource group and create the hub side of the peering.
#
# Note: creating a peering requires `peer/action` on *both* linked vnets. Because
# a single identity holds `peer/action` at the spoke scope (above) and at the hub
# scope (here), the cross-scope `LinkedAuthorizationFailed` that a split identity
# would hit is avoided.
#
resource "azurerm_role_definition" "backplane_hub" {
  name        = "${var.name}-deploy-hub"
  description = "Enables the ${var.name} spoke network building block to peer into the hub vnet"
  scope       = var.hub_scope

  permissions {
    actions = [
      "Microsoft.Resources/subscriptions/resourceGroups/read",
      "Microsoft.Network/virtualNetworks/read",
      "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/read",
      "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/write",
      "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/delete",
      "Microsoft.Network/virtualNetworks/peer/action",
    ]
  }
}

resource "azurerm_role_assignment" "backplane" {
  scope              = var.scope
  role_definition_id = azurerm_role_definition.backplane.role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.backplane.principal_id
}

resource "azurerm_role_assignment" "backplane_hub" {
  scope              = var.hub_scope
  role_definition_id = azurerm_role_definition.backplane_hub.role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.backplane.principal_id
}
