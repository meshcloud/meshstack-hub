data "azurerm_subscription" "current" {}

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

resource "azuread_application" "buildingblock_deploy_hub" {
  count = var.create_hub_service_principal_name != null ? 1 : 0

  display_name = "${var.name}-${var.create_hub_service_principal_name}"
}

resource "azuread_service_principal" "buildingblock_deploy_hub" {
  count = var.create_hub_service_principal_name != null ? 1 : 0

  client_id                    = azuread_application.buildingblock_deploy_hub[0].client_id
  app_role_assignment_required = false
}

resource "azuread_application_federated_identity_credential" "buildingblock_deploy_hub" {
  count = var.create_hub_service_principal_name != null && var.hub_workload_identity_federation != null ? 1 : 0

  application_id = azuread_application.buildingblock_deploy_hub[0].id
  display_name   = var.create_hub_service_principal_name
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = var.hub_workload_identity_federation.issuer
  subject        = var.hub_workload_identity_federation.subject
}

resource "azuread_application_password" "buildingblock_deploy_hub" {
  count = var.create_hub_service_principal_name != null && var.hub_workload_identity_federation == null ? 1 : 0

  application_id = azuread_application.buildingblock_deploy_hub[0].id
  display_name   = "${var.create_hub_service_principal_name}-password"
}

resource "azurerm_role_definition" "buildingblock_deploy" {
  name        = "${var.name}-deploy"
  scope       = var.scope
  description = "Enables deployment of the ${var.name} building block to subscriptions"

  permissions {
    actions = [
      # Key Vault
      "Microsoft.KeyVault/vaults/read",
      "*/register/action",
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

      # Virtual Networks
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

      # Role Assignments
      "Microsoft.Authorization/roleAssignments/read",
      "Microsoft.Authorization/roleAssignments/write",
      "Microsoft.Authorization/roleAssignments/delete",
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

resource "azurerm_role_definition" "buildingblock_deploy_hub" {
  name        = "${var.name}-deploy-hub"
  description = "Enables deployment of the ${var.name} building block to the hub (for private endpoint peering)"
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

resource "azurerm_role_definition" "buildingblock_hub_to_landingzone" {
  name        = "${var.name}-hub-to-landingzone"
  description = "Allows hub service principal to peer back to landing zone vnets"
  scope       = var.scope

  permissions {
    actions = [
      "Microsoft.Network/virtualNetworks/read",
      "Microsoft.Network/virtualNetworks/peer/action",
    ]
  }
}

resource "azurerm_role_definition" "buildingblock_landingzone_to_hub" {
  name        = "${var.name}-landingzone-to-hub"
  description = "Allows landing zone service principal to peer to hub vnets"
  scope       = var.hub_scope

  permissions {
    actions = [
      "Microsoft.Resources/subscriptions/resourceGroups/read",
      "Microsoft.Network/virtualNetworks/read",
      "Microsoft.Network/virtualNetworks/peer/action",
    ]
  }
}

resource "azurerm_role_assignment" "existing_principals_hub" {
  for_each = var.existing_hub_principal_ids

  role_definition_id = azurerm_role_definition.buildingblock_deploy_hub.role_definition_resource_id
  description        = azurerm_role_definition.buildingblock_deploy_hub.description
  principal_id       = each.value
  scope              = var.hub_scope
}

resource "azurerm_role_assignment" "created_principal_hub" {
  count = var.create_hub_service_principal_name != null ? 1 : 0

  role_definition_id = azurerm_role_definition.buildingblock_deploy_hub.role_definition_resource_id
  description        = azurerm_role_definition.buildingblock_deploy_hub.description
  principal_id       = azuread_service_principal.buildingblock_deploy_hub[0].object_id
  scope              = var.hub_scope
}

resource "azurerm_role_assignment" "existing_principals_hub_to_landingzone" {
  for_each = var.existing_hub_principal_ids

  role_definition_id = azurerm_role_definition.buildingblock_hub_to_landingzone.role_definition_resource_id
  principal_id       = each.value
  scope              = var.scope
}

resource "azurerm_role_assignment" "created_principal_hub_to_landingzone" {
  count = var.create_hub_service_principal_name != null ? 1 : 0

  role_definition_id = azurerm_role_definition.buildingblock_hub_to_landingzone.role_definition_resource_id
  principal_id       = azuread_service_principal.buildingblock_deploy_hub[0].object_id
  scope              = var.scope
}

resource "azurerm_role_assignment" "existing_principals_landingzone_to_hub" {
  for_each = var.existing_principal_ids

  role_definition_id = azurerm_role_definition.buildingblock_landingzone_to_hub.role_definition_resource_id
  principal_id       = each.value
  scope              = var.hub_scope
}

resource "azurerm_role_assignment" "created_principal_landingzone_to_hub" {
  count = var.create_service_principal_name != null ? 1 : 0

  role_definition_id = azurerm_role_definition.buildingblock_landingzone_to_hub.role_definition_resource_id
  principal_id       = azuread_service_principal.buildingblock_deploy[0].object_id
  scope              = var.hub_scope
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
