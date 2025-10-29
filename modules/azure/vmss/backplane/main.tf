# Service Principal Creation
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

# Role Definition
resource "azurerm_role_definition" "buildingblock_deploy" {
  name        = "${var.name}-deploy"
  description = "Enables deployment of the ${var.name} building block to subscriptions"
  scope       = var.scope
  permissions {
    actions = [
      # Virtual Machine Scale Sets
      "Microsoft.Compute/virtualMachineScaleSets/read",
      "Microsoft.Compute/virtualMachineScaleSets/write",
      "Microsoft.Compute/virtualMachineScaleSets/delete",
      "Microsoft.Compute/virtualMachineScaleSets/*/read",
      "Microsoft.Compute/virtualMachineScaleSets/*/write",
      "Microsoft.Compute/virtualMachineScaleSets/*/delete",
      "Microsoft.Compute/virtualMachineScaleSets/virtualmachines/read",
      "Microsoft.Compute/virtualMachineScaleSets/virtualmachines/write",
      "Microsoft.Compute/virtualMachineScaleSets/virtualmachines/delete",
      "Microsoft.Compute/disks/read",
      "Microsoft.Compute/disks/write",
      "Microsoft.Compute/disks/delete",

      # Load Balancer
      "Microsoft.Network/loadBalancers/read",
      "Microsoft.Network/loadBalancers/write",
      "Microsoft.Network/loadBalancers/delete",
      "Microsoft.Network/loadBalancers/backendAddressPools/read",
      "Microsoft.Network/loadBalancers/backendAddressPools/write",
      "Microsoft.Network/loadBalancers/backendAddressPools/delete",
      "Microsoft.Network/loadBalancers/backendAddressPools/join/action",
      "Microsoft.Network/loadBalancers/frontendIPConfigurations/read",
      "Microsoft.Network/loadBalancers/inboundNatRules/read",
      "Microsoft.Network/loadBalancers/inboundNatRules/write",
      "Microsoft.Network/loadBalancers/inboundNatRules/delete",
      "Microsoft.Network/loadBalancers/loadBalancingRules/read",
      "Microsoft.Network/loadBalancers/networkInterfaces/read",
      "Microsoft.Network/loadBalancers/probes/read",
      "Microsoft.Network/loadBalancers/probes/write",
      "Microsoft.Network/loadBalancers/probes/delete",
      "Microsoft.Network/loadBalancers/probes/join/action",

      # Network Interface
      "Microsoft.Network/networkInterfaces/read",
      "Microsoft.Network/networkInterfaces/write",
      "Microsoft.Network/networkInterfaces/delete",
      "Microsoft.Network/networkInterfaces/join/action",

      # Public IP
      "Microsoft.Network/publicIPAddresses/read",
      "Microsoft.Network/publicIPAddresses/write",
      "Microsoft.Network/publicIPAddresses/delete",
      "Microsoft.Network/publicIPAddresses/join/action",

      # Network Security Group
      "Microsoft.Network/networkSecurityGroups/read",
      "Microsoft.Network/networkSecurityGroups/write",
      "Microsoft.Network/networkSecurityGroups/delete",
      "Microsoft.Network/networkSecurityGroups/join/action",
      "Microsoft.Network/networkSecurityGroups/securityRules/read",
      "Microsoft.Network/networkSecurityGroups/securityRules/write",
      "Microsoft.Network/networkSecurityGroups/securityRules/delete",

      # Virtual Network and Subnet
      "Microsoft.Network/virtualNetworks/read",
      "Microsoft.Network/virtualNetworks/write",
      "Microsoft.Network/virtualNetworks/delete",
      "Microsoft.Network/virtualNetworks/subnets/read",
      "Microsoft.Network/virtualNetworks/subnets/write",
      "Microsoft.Network/virtualNetworks/subnets/delete",
      "Microsoft.Network/virtualNetworks/subnets/join/action",

      # Autoscale Settings
      "Microsoft.Insights/autoscalesettings/read",
      "Microsoft.Insights/autoscalesettings/write",
      "Microsoft.Insights/autoscalesettings/delete",
      "Microsoft.Insights/autoscalesettings/providers/Microsoft.Insights/diagnosticSettings/read",
      "Microsoft.Insights/autoscalesettings/providers/Microsoft.Insights/diagnosticSettings/write",

      # Monitoring and Diagnostics
      "Microsoft.Insights/metrics/read",
      "Microsoft.Insights/metricDefinitions/read",

      # Resource Groups
      "Microsoft.Resources/subscriptions/resourcegroups/read",
      "Microsoft.Resources/subscriptions/resourcegroups/write",
      "Microsoft.Resources/subscriptions/resourcegroups/delete",

      # Managed Identities
      "Microsoft.ManagedIdentity/userAssignedIdentities/assign/action",

      # Permission to activate/register required Resource Providers
      "*/register/action"
    ]
  }
}

# Role Assignments for existing principals
resource "azurerm_role_assignment" "existing_principals" {
  for_each = var.existing_principal_ids

  role_definition_id = azurerm_role_definition.buildingblock_deploy.role_definition_resource_id
  principal_id       = each.value
  scope              = var.scope
}

# Role Assignment for created service principal
resource "azurerm_role_assignment" "created_principal" {
  count = var.create_service_principal_name != null ? 1 : 0

  role_definition_id = azurerm_role_definition.buildingblock_deploy.role_definition_resource_id
  principal_id       = azuread_service_principal.buildingblock_deploy[0].object_id
  scope              = var.scope
}
