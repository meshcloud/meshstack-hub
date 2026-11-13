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
  audience                  = [var.workload_identity_federation.audience]
  issuer                    = var.workload_identity_federation.issuer
  subject                   = each.value
}

resource "azurerm_federated_identity_credential" "trusted_runner" {
  for_each = { for identity in var.trusted_runner_identities : identity.runner_uuid => identity }

  depends_on = [azurerm_federated_identity_credential.backplane]

  lifecycle {
    precondition {
      condition     = each.value.subject != null
      error_message = "The building block runner ${each.key} is a trusted runner, but no version of the definition runs on it, so there is nothing to trust. Remove it from meshstack.trusted_runner_refs."
    }
  }

  name                      = "trusted-runner-${each.key}"
  user_assigned_identity_id = azurerm_user_assigned_identity.backplane.id
  audience                  = [each.value.audience]
  issuer                    = each.value.issuer
  subject                   = each.value.subject
}

resource "azurerm_role_definition" "backplane" {
  name        = "${var.name}-deploy"
  description = "Enables deployment of the ${var.name} building block to subscriptions"
  scope       = var.scope
  permissions {
    actions = [
      # resource manager
      "*/register/action",
      # storage accounts
      "Microsoft.Storage/storageAccounts/write",
      "Microsoft.Storage/storageAccounts/read",
      "Microsoft.Storage/storageAccounts/delete",
      "Microsoft.Storage/storageAccounts/managementPolicies/write",
      "Microsoft.Storage/storageAccounts/managementPolicies/read",
      "Microsoft.Storage/storageAccounts/managementPolicies/delete",
      "Microsoft.Storage/storageAccounts/objectReplicationPolicies/write",
      "Microsoft.Storage/storageAccounts/objectReplicationPolicies/read",
      "Microsoft.Storage/storageAccounts/objectReplicationPolicies/delete",
      "Microsoft.Storage/storageAccounts/listKeys/action",
      # azurerm >= 5.4.0 reads migration status on every Storage Account encode (including destroy)
      "Microsoft.Storage/storageAccounts/accountMigrations/read",

      # resource groups
      "Microsoft.Resources/subscriptions/resourcegroups/read",
      "Microsoft.Resources/subscriptions/resourcegroups/write",
      "Microsoft.Resources/subscriptions/resourcegroups/delete",

      # sub-resources
      "Microsoft.Storage/storageAccounts/blobServices/read",
      "Microsoft.Storage/storageAccounts/blobServices/write",
      "Microsoft.Storage/storageAccounts/fileServices/read",
      "Microsoft.Storage/storageAccounts/fileServices/write",
      "Microsoft.Storage/storageAccounts/queueServices/read",
      "Microsoft.Storage/storageAccounts/queueServices/write",
      "Microsoft.Storage/storageAccounts/tableServices/read",
      "Microsoft.Storage/storageAccounts/tableServices/write",
    ]
  }
}

resource "azurerm_role_assignment" "backplane" {
  scope              = var.scope
  role_definition_id = azurerm_role_definition.backplane.role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.backplane.principal_id
}
