resource "azurerm_role_definition" "buildingblock_deploy" {
  name        = "${var.name}-deploy"
  scope       = var.scope
  description = "Enables deployment of the ${var.name} building block to subscriptions"

  permissions {
    actions = [
      "Microsoft.ContainerService/managedClusters/read",
      "Microsoft.ContainerService/managedClusters/write",
      "Microsoft.ContainerService/managedClusters/delete",
      "Microsoft.ContainerService/managedClusters/listClusterAdminCredential/action",
      "Microsoft.ContainerService/managedClusters/listClusterUserCredential/action",
      "Microsoft.ContainerService/managedClusters/listClusterMonitoringUserCredential/action",
      "Microsoft.ContainerService/managedClusters/accessProfiles/listCredential/action",
      "Microsoft.ContainerService/managedClusters/accessProfiles/read",
      "Microsoft.ContainerService/managedClusters/agentPools/read",
      "Microsoft.ContainerService/managedClusters/agentPools/write",
      "Microsoft.ContainerService/managedClusters/agentPools/delete",
      "Microsoft.Network/virtualNetworks/read",
      "Microsoft.Network/virtualNetworks/write",
      "Microsoft.Network/virtualNetworks/delete",
      "Microsoft.Network/virtualNetworks/subnets/read",
      "Microsoft.Network/virtualNetworks/subnets/write",
      "Microsoft.Network/virtualNetworks/subnets/delete",
      "Microsoft.Network/virtualNetworks/subnets/join/action",
      "Microsoft.Network/networkInterfaces/read",
      "Microsoft.Network/networkSecurityGroups/read",
      "Microsoft.Network/networkSecurityGroups/write",
      "Microsoft.Network/networkSecurityGroups/delete",
      "Microsoft.Network/publicIPAddresses/read",
      "Microsoft.Network/publicIPAddresses/write",
      "Microsoft.Network/publicIPAddresses/delete",
      "Microsoft.Network/loadBalancers/read",
      "Microsoft.Network/loadBalancers/write",
      "Microsoft.Network/loadBalancers/delete",
      "Microsoft.Resources/deployments/read",
      "Microsoft.Resources/deployments/write",
      "Microsoft.Resources/deployments/delete",
      "Microsoft.Resources/subscriptions/resourceGroups/read",
      "Microsoft.Resources/subscriptions/resourceGroups/write",
      "Microsoft.Resources/subscriptions/resourceGroups/delete",
      "Microsoft.OperationalInsights/workspaces/read",
      "Microsoft.OperationalInsights/workspaces/write",
      "Microsoft.OperationalInsights/workspaces/delete",
      "Microsoft.Insights/diagnosticSettings/read",
      "Microsoft.Insights/diagnosticSettings/write",
      "Microsoft.Insights/diagnosticSettings/delete",
      "Microsoft.Authorization/roleAssignments/read"
    ]
  }
}

resource "azurerm_role_assignment" "buildingblock_deploy" {
  for_each = var.principal_ids

  role_definition_id = azurerm_role_definition.buildingblock_deploy.role_definition_resource_id
  principal_id       = each.value
  scope              = var.scope
}
