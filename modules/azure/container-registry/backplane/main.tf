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
      # Container Registry
      "Microsoft.ContainerRegistry/registries/read",
      "Microsoft.ContainerRegistry/registries/write",
      "Microsoft.ContainerRegistry/registries/delete",
      "Microsoft.ContainerRegistry/registries/listCredentials/action",
      "Microsoft.ContainerRegistry/registries/regenerateCredential/action",
      "Microsoft.ContainerRegistry/registries/listUsages/action",
      "Microsoft.ContainerRegistry/registries/importImage/action",
      "Microsoft.ContainerRegistry/registries/webhooks/read",
      "Microsoft.ContainerRegistry/registries/webhooks/write",
      "Microsoft.ContainerRegistry/registries/webhooks/delete",
      "Microsoft.ContainerRegistry/registries/replications/read",
      "Microsoft.ContainerRegistry/registries/replications/write",
      "Microsoft.ContainerRegistry/registries/replications/delete",
      "Microsoft.ContainerRegistry/registries/scopeMaps/read",
      "Microsoft.ContainerRegistry/registries/scopeMaps/write",
      "Microsoft.ContainerRegistry/registries/scopeMaps/delete",
      "Microsoft.ContainerRegistry/registries/tokens/read",
      "Microsoft.ContainerRegistry/registries/tokens/write",
      "Microsoft.ContainerRegistry/registries/tokens/delete",

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
      "Microsoft.Network/privateDnsZones/virtualNetworkLinks/read",
      "Microsoft.Network/privateDnsZones/virtualNetworkLinks/write",
      "Microsoft.Network/privateDnsZones/virtualNetworkLinks/delete",
      "Microsoft.Network/privateDnsZones/A/read",
      "Microsoft.Network/privateDnsZones/A/write",
      "Microsoft.Network/privateDnsZones/A/delete",

      # Virtual Networks
      "Microsoft.Network/virtualNetworks/read",
      "Microsoft.Network/virtualNetworks/write",
      "Microsoft.Network/virtualNetworks/delete",
      "Microsoft.Network/virtualNetworks/subnets/read",
      "Microsoft.Network/virtualNetworks/subnets/write",
      "Microsoft.Network/virtualNetworks/subnets/delete",
      "Microsoft.Network/virtualNetworks/subnets/join/action",
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

      # Role Assignments (for AKS integration)
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
