# Privileged bootstrap identity for the Azure Landing Zone reference architecture.
#
# The reference architecture's building block run creates management groups, the meshStack platform
# service principals (via terraform-azure-meshplatform), management-group role assignments, the hub
# network and the per-building-block backplanes. That run therefore needs a highly privileged Azure
# identity. This module provisions a User-Assigned Managed Identity federated to the reference
# architecture's building block definition, so meshStack executes the ordered run as this identity —
# no stored secret. Apply it (via meshstack_integration.tf) with an identity that is Owner on the
# scope and can grant Microsoft Graph app roles (Global Admin / Privileged Role Administrator).

locals {
  # Accept a full resource path as-is, a bare subscription GUID as a subscription scope, or any other
  # bare value as a management group name — azurerm_role_assignment.scope needs the full path.
  scope = startswith(var.scope, "/") ? var.scope : (
    can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.scope))
    ? "/subscriptions/${var.scope}"
    : "/providers/Microsoft.Management/managementGroups/${var.scope}"
  )
}

data "azuread_service_principal" "msgraph" {
  client_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph
}

resource "azurerm_resource_group" "bootstrap" {
  name     = var.name
  location = var.location
}

resource "azurerm_user_assigned_identity" "bootstrap" {
  name                = var.name
  location            = var.location
  resource_group_name = azurerm_resource_group.bootstrap.name
}

resource "azurerm_federated_identity_credential" "bootstrap" {
  for_each = { for i, s in var.workload_identity_federation.subjects : tostring(i) => s }

  name                      = "subject-${each.key}"
  user_assigned_identity_id = azurerm_user_assigned_identity.bootstrap.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = var.workload_identity_federation.issuer
  subject                   = each.value
}

# Azure RBAC: Owner at the scope so the run can create management groups beneath it, custom role
# definitions and role assignments, resource groups, User-Assigned Managed Identities, and the hub
# vnet/firewall. Set the scope high enough to cover everything the architecture provisions — e.g.
# the tenant root management group.
resource "azurerm_role_assignment" "owner" {
  scope                = local.scope
  role_definition_name = "Owner"
  principal_id         = azurerm_user_assigned_identity.bootstrap.principal_id
}

# Microsoft Entra: allow the run to create the meshStack platform service principals (replicator,
# metering and — for the MCA provisioning model — mca) that the meshplatform module registers.
resource "azuread_app_role_assignment" "graph_application_readwrite" {
  app_role_id         = data.azuread_service_principal.msgraph.app_role_ids["Application.ReadWrite.All"]
  principal_object_id = azurerm_user_assigned_identity.bootstrap.principal_id
  resource_object_id  = data.azuread_service_principal.msgraph.object_id
}

# Directory.Read.All — the platform integration reads the tenant's initial domain
# (data.azuread_domains) and the meshplatform module reads directory objects.
resource "azuread_app_role_assignment" "graph_directory_read" {
  app_role_id         = data.azuread_service_principal.msgraph.app_role_ids["Directory.Read.All"]
  principal_object_id = azurerm_user_assigned_identity.bootstrap.principal_id
  resource_object_id  = data.azuread_service_principal.msgraph.object_id
}

# AppRoleAssignment.ReadWrite.All — the meshplatform module grants the replicator service principal
# its own Graph app roles (directory/group/user read); assigning app roles to another SP requires
# this permission on the identity performing the run.
resource "azuread_app_role_assignment" "graph_approleassignment_readwrite" {
  app_role_id         = data.azuread_service_principal.msgraph.app_role_ids["AppRoleAssignment.ReadWrite.All"]
  principal_object_id = azurerm_user_assigned_identity.bootstrap.principal_id
  resource_object_id  = data.azuread_service_principal.msgraph.object_id
}

# Enterprise-Scale management group hierarchy, created here in the bootstrap phase so the management
# groups already EXIST when the ordered building block run reaches the meshplatform module (which
# looks them up via a data source — creating and reading them in the same run is a catch-22). The
# building block then adopts them via `import` blocks and manages them going forward. Uses the same
# parent (scope) + name_prefix as the building block so the names match for the import.
module "management_groups" {
  source = "./modules/management-groups"

  parent_management_group_id = var.scope
  name_prefix                = var.management_group_name_prefix
}
