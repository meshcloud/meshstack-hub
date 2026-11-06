data "azurerm_role_definition" "openai_user" {
  name  = "Cognitive Services OpenAI User"
  scope = var.scope
}

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
  for_each = { for index, identity in var.workload_identity_federations : tostring(index) => identity }

  name                      = "subject-${each.key}"
  user_assigned_identity_id = azurerm_user_assigned_identity.backplane.id
  audience                  = [each.value.audience]
  issuer                    = each.value.issuer
  subject                   = each.value.subject
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

      # Resource groups
      "Microsoft.Resources/subscriptions/resourcegroups/read",
      "Microsoft.Resources/subscriptions/resourcegroups/write",
      "Microsoft.Resources/subscriptions/resourcegroups/delete",

      # AI Services accounts and model deployments
      "Microsoft.CognitiveServices/accounts/read",
      "Microsoft.CognitiveServices/accounts/write",
      "Microsoft.CognitiveServices/accounts/delete",
      # azurerm reads the keys on every refresh; they are useless with local auth disabled.
      "Microsoft.CognitiveServices/accounts/listKeys/action",
      "Microsoft.CognitiveServices/accounts/deployments/read",
      "Microsoft.CognitiveServices/accounts/deployments/write",
      "Microsoft.CognitiveServices/accounts/deployments/delete",
      "Microsoft.CognitiveServices/locations/operationresults/read",

      # Purging the soft-deleted account on destroy
      "Microsoft.CognitiveServices/deletedAccounts/read",
      "Microsoft.CognitiveServices/locations/resourceGroups/deletedAccounts/read",
      "Microsoft.CognitiveServices/locations/resourceGroups/deletedAccounts/delete",

      # Granting the application's identity access, limited by the condition below
      "Microsoft.Authorization/roleAssignments/read",
      "Microsoft.Authorization/roleAssignments/write",
      "Microsoft.Authorization/roleAssignments/delete",
    ]
  }
}

locals {
  openai_user_role_guid = basename(data.azurerm_role_definition.openai_user.role_definition_id)
}

resource "azurerm_role_assignment" "backplane" {
  scope              = var.scope
  role_definition_id = azurerm_role_definition.backplane.role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.backplane.principal_id

  # Without this the identity could grant itself Owner. The condition allows writing and deleting
  # role assignments of the one data-plane role the building block hands out.
  condition_version = "2.0"
  condition         = <<-EOT
    (
     (
      !(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})
     )
     OR
     (
      @Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${local.openai_user_role_guid}}
     )
    )
    AND
    (
     (
      !(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})
     )
     OR
     (
      @Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${local.openai_user_role_guid}}
     )
    )
  EOT
}
