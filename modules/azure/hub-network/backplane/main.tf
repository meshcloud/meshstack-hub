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
# Hub deploy role — grants the automation identity everything it needs to build and
# maintain the central hub in the connectivity scope: the hub resource group, the hub
# vnet and its subnets, the route table, and (optionally) the Azure Firewall with its
# public IPs.
#
resource "azurerm_role_definition" "backplane" {
  name        = "${var.name}-deploy"
  description = "Enables deployment of the ${var.name} hub network building block to the connectivity scope"
  scope       = var.scope

  permissions {
    actions = [
      # Register resource providers in Azure Resource Manager
      "*/register/action",
      "Microsoft.Resources/subscriptions/providers/read",

      # Hub resource group
      "Microsoft.Resources/subscriptions/resourceGroups/read",
      "Microsoft.Resources/subscriptions/resourceGroups/write",
      "Microsoft.Resources/subscriptions/resourceGroups/delete",

      # Hub virtual network + subnets + peering (spokes peer in from the outside)
      "Microsoft.Network/virtualNetworks/*",
      "Microsoft.Network/routeTables/*",

      # Azure Firewall + its public IPs
      "Microsoft.Network/publicIPAddresses/*",
      "Microsoft.Network/publicIPPrefixes/*",
      "Microsoft.Network/azureFirewalls/*",
      "Microsoft.Network/firewallPolicies/*",
    ]
  }
}

resource "azurerm_role_assignment" "backplane" {
  scope              = var.scope
  role_definition_id = azurerm_role_definition.backplane.role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.backplane.principal_id
}
