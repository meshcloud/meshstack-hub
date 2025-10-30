output "role_definition_id" {
  value       = azurerm_role_definition.buildingblock_deploy.id
  description = "The ID of the role definition that enables deployment of the building block."
}

output "role_definition_name" {
  value       = azurerm_role_definition.buildingblock_deploy.name
  description = "The name of the role definition that enables deployment of the building block."
}

output "role_assignment_ids" {
  value = concat(
    [for id in azurerm_role_assignment.existing_principals : id.id],
    var.create_service_principal_name != null ? [azurerm_role_assignment.created_principal[0].id] : []
  )
  description = "The IDs of the role assignments for all service principals."
}

output "role_assignment_principal_ids" {
  value = concat(
    [for id in azurerm_role_assignment.existing_principals : id.principal_id],
    var.create_service_principal_name != null ? [azurerm_role_assignment.created_principal[0].principal_id] : []
  )
  description = "The principal IDs of all service principals that have been assigned the role."
}

output "created_service_principal" {
  value = var.create_service_principal_name != null ? {
    object_id    = azuread_service_principal.buildingblock_deploy[0].object_id
    client_id    = azuread_service_principal.buildingblock_deploy[0].client_id
    display_name = azuread_service_principal.buildingblock_deploy[0].display_name
    name         = var.create_service_principal_name
  } : null
  description = "Information about the created service principal."
}

output "created_application" {
  value = var.create_service_principal_name != null ? {
    object_id    = azuread_application.buildingblock_deploy[0].object_id
    client_id    = azuread_application.buildingblock_deploy[0].client_id
    display_name = azuread_application.buildingblock_deploy[0].display_name
  } : null
  description = "Information about the created Azure AD application."
}

output "workload_identity_federation" {
  value = var.create_service_principal_name != null && var.workload_identity_federation != null ? {
    credential_id = azuread_application_federated_identity_credential.buildingblock_deploy[0].credential_id
    display_name  = azuread_application_federated_identity_credential.buildingblock_deploy[0].display_name
    issuer        = azuread_application_federated_identity_credential.buildingblock_deploy[0].issuer
    subject       = azuread_application_federated_identity_credential.buildingblock_deploy[0].subject
    audiences     = azuread_application_federated_identity_credential.buildingblock_deploy[0].audiences
  } : null
  description = "Information about the created workload identity federation credential."
}

output "application_password" {
  value = var.create_service_principal_name != null && var.workload_identity_federation == null ? {
    key_id       = azuread_application_password.buildingblock_deploy[0].key_id
    display_name = azuread_application_password.buildingblock_deploy[0].display_name
  } : null
  description = "Information about the created application password (excludes the actual password value for security)."
  sensitive   = true
}

output "scope" {
  value       = var.scope
  description = "The scope where the role definition and role assignments are applied."
}

output "hub_scope" {
  value       = var.hub_scope
  description = "The scope (management group or subscription) where VNet peering role is applied."
}

output "hub_role_definition_id" {
  value       = azurerm_role_definition.buildingblock_deploy_hub.id
  description = "The ID of the role definition that enables deployment of the building block to the hub."
}

output "hub_role_definition_name" {
  value       = azurerm_role_definition.buildingblock_deploy_hub.name
  description = "The name of the role definition that enables deployment of the building block to the hub."
}

output "hub_role_assignment_ids" {
  value = concat(
    [for id in azurerm_role_assignment.existing_principals_hub : id.id],
    var.create_hub_service_principal_name != null ? [azurerm_role_assignment.created_principal_hub[0].id] : []
  )
  description = "The IDs of the hub role assignments for all service principals."
}

output "hub_role_assignment_principal_ids" {
  value = concat(
    [for id in azurerm_role_assignment.existing_principals_hub : id.principal_id],
    var.create_hub_service_principal_name != null ? [azurerm_role_assignment.created_principal_hub[0].principal_id] : []
  )
  description = "The principal IDs of all service principals that have been assigned the hub role."
}

output "created_hub_service_principal" {
  value = var.create_hub_service_principal_name != null ? {
    object_id    = azuread_service_principal.buildingblock_deploy_hub[0].object_id
    client_id    = azuread_service_principal.buildingblock_deploy_hub[0].client_id
    display_name = azuread_service_principal.buildingblock_deploy_hub[0].display_name
    name         = var.create_hub_service_principal_name
  } : null
  description = "Information about the created hub service principal."
}

output "created_hub_application" {
  value = var.create_hub_service_principal_name != null ? {
    object_id    = azuread_application.buildingblock_deploy_hub[0].object_id
    client_id    = azuread_application.buildingblock_deploy_hub[0].client_id
    display_name = azuread_application.buildingblock_deploy_hub[0].display_name
  } : null
  description = "Information about the created hub Azure AD application."
}

output "hub_workload_identity_federation" {
  value = var.create_hub_service_principal_name != null && var.hub_workload_identity_federation != null ? {
    credential_id = azuread_application_federated_identity_credential.buildingblock_deploy_hub[0].credential_id
    display_name  = azuread_application_federated_identity_credential.buildingblock_deploy_hub[0].display_name
    issuer        = azuread_application_federated_identity_credential.buildingblock_deploy_hub[0].issuer
    subject       = azuread_application_federated_identity_credential.buildingblock_deploy_hub[0].subject
    audiences     = azuread_application_federated_identity_credential.buildingblock_deploy_hub[0].audiences
  } : null
  description = "Information about the created hub workload identity federation credential."
}

output "hub_application_password" {
  value = var.create_hub_service_principal_name != null && var.hub_workload_identity_federation == null ? {
    key_id       = azuread_application_password.buildingblock_deploy_hub[0].key_id
    display_name = azuread_application_password.buildingblock_deploy_hub[0].display_name
  } : null
  description = "Information about the created hub application password (excludes the actual password value for security)."
  sensitive   = true
}
