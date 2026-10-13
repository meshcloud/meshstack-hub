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
  description = "Enables deployment of the ${var.name} building block to landing zone subscriptions"
  scope       = var.scope

  permissions {
    actions = [
      # Register resource providers in Azure Resource Manager
      "*/register/action",
      "Microsoft.Resources/subscriptions/providers/read",

      # Key Vault
      "Microsoft.KeyVault/vaults/read",
      "Microsoft.KeyVault/vaults/write",
      "Microsoft.KeyVault/vaults/delete",
      "Microsoft.KeyVault/locations/deletedVaults/read",
      "Microsoft.KeyVault/locations/deletedVaults/purge/action",
      "Microsoft.KeyVault/vaults/PrivateEndpointConnectionsApproval/action",

      # Private Endpoints
      "Microsoft.Network/privateEndpoints/read",
      "Microsoft.Network/privateEndpoints/write",
      "Microsoft.Network/privateEndpoints/delete",
      "Microsoft.Network/privateEndpoints/privateDnsZoneGroups/read",
      "Microsoft.Network/privateEndpoints/privateDnsZoneGroups/write",
      "Microsoft.Network/privateEndpoints/privateDnsZoneGroups/delete",

      # Private DNS Zones
      "Microsoft.Network/privateDnsZones/read",
      "Microsoft.Network/privateDnsZones/write",
      "Microsoft.Network/privateDnsZones/delete",
      "Microsoft.Network/privateDnsZones/join/action",
      "Microsoft.Network/privateDnsZones/virtualNetworkLinks/read",
      "Microsoft.Network/privateDnsZones/virtualNetworkLinks/write",
      "Microsoft.Network/privateDnsZones/virtualNetworkLinks/delete",
      "Microsoft.Network/privateDnsZones/A/read",
      "Microsoft.Network/privateDnsZones/A/write",
      "Microsoft.Network/privateDnsZones/A/delete",
      "Microsoft.Network/privateDnsZones/SOA/read",

      # Virtual Networks, including the landing zone side of the hub peering
      "Microsoft.Network/virtualNetworks/read",
      "Microsoft.Network/virtualNetworks/write",
      "Microsoft.Network/virtualNetworks/delete",
      "Microsoft.Network/virtualNetworks/subnets/read",
      "Microsoft.Network/virtualNetworks/subnets/write",
      "Microsoft.Network/virtualNetworks/subnets/delete",
      "Microsoft.Network/virtualNetworks/subnets/join/action",
      "Microsoft.Network/virtualNetworks/join/action",
      "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/read",
      "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/write",
      "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/delete",
      "Microsoft.Network/virtualNetworks/peer/action",

      # Resource Groups
      "Microsoft.Resources/subscriptions/resourceGroups/read",
      "Microsoft.Resources/subscriptions/resourceGroups/write",
      "Microsoft.Resources/subscriptions/resourceGroups/delete",

      # Deployments
      "Microsoft.Resources/deployments/read",
      "Microsoft.Resources/deployments/write",
      "Microsoft.Resources/deployments/delete",
    ]
  }
}

resource "azurerm_role_assignment" "backplane" {
  scope              = var.scope
  role_definition_id = azurerm_role_definition.backplane.role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.backplane.principal_id
}

# The building block peers both sides of a private Key Vault's vnet with the hub. A peering needs
# `peer/action` on both vnets, so the same identity holds it at the landing zone scope (above) and
# here, which spares the cross-scope `LinkedAuthorizationFailed` of a split identity.
resource "azurerm_role_definition" "backplane_hub" {
  lifecycle {
    enabled = var.hub_scope != null
  }

  name        = "${var.name}-deploy-hub"
  description = "Enables the ${var.name} building block to peer private Key Vault vnets into the hub vnet"
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

resource "azurerm_role_assignment" "backplane_hub" {
  lifecycle {
    enabled = var.hub_scope != null
  }

  scope              = var.hub_scope
  role_definition_id = azurerm_role_definition.backplane_hub.role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.backplane.principal_id
}
