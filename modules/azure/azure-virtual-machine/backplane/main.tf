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


# Create federated identity credentials
resource "azuread_application_federated_identity_credential" "buildingblock_deploy" {
  count = var.create_service_principal_name != null && var.workload_identity_federation != null ? 1 : 0

  application_id = azuread_application.buildingblock_deploy[0].id
  display_name   = var.create_service_principal_name
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = var.workload_identity_federation.issuer
  subject        = var.workload_identity_federation.subject
}

# Create application password (when not using workload identity federation)
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
      # Virtual Machines
      "Microsoft.Compute/virtualMachines/read",
      "Microsoft.Compute/virtualMachines/write",
      "Microsoft.Compute/virtualMachines/delete",
      "Microsoft.Compute/disks/read",
      "Microsoft.Compute/disks/write",
      "Microsoft.Compute/disks/delete",

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

      # Network Security Rules
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

      # Resource Groups
      "Microsoft.Resources/subscriptions/resourcegroups/read",
      "Microsoft.Resources/subscriptions/resourcegroups/write",
      "Microsoft.Resources/subscriptions/resourcegroups/delete",

      # Managed Identities (for system-assigned identity)
      "Microsoft.ManagedIdentity/userAssignedIdentities/assign/action",

      # Permission we need to activate/register required Resource Providers
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
