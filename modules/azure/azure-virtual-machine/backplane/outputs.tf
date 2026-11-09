output "role_definition_id" {
  value       = azurerm_role_definition.buildingblock_deploy.id
  description = "The ID of the role definition that enables deployment of the building block to subscriptions."
}

output "role_definition_name" {
  value       = azurerm_role_definition.buildingblock_deploy.name
  description = "The name of the role definition that enables deployment of the building block to subscriptions."
}

output "role_assignment_ids" {
  value = concat(
    [for id in azurerm_role_assignment.existing_principals : id.id],
    var.create_service_principal_name != null ? [azurerm_role_assignment.created_principal.id] : []
  )
  description = "The IDs of the role assignments for all service principals."
}

output "role_assignment_principal_ids" {
  value = concat(
    [for id in azurerm_role_assignment.existing_principals : id.principal_id],
    var.create_service_principal_name != null ? [azurerm_role_assignment.created_principal.principal_id] : []
  )
  description = "The principal IDs of all service principals that have been assigned the role."
}

output "created_service_principal" {
  value = var.create_service_principal_name != null ? {
    object_id    = azuread_service_principal.buildingblock_deploy.object_id
    client_id    = azuread_service_principal.buildingblock_deploy.client_id
    display_name = azuread_service_principal.buildingblock_deploy.display_name
    name         = var.create_service_principal_name
  } : null
  description = "Information about the created service principal."
}

output "created_application" {
  value = var.create_service_principal_name != null ? {
    object_id    = azuread_application.buildingblock_deploy.object_id
    client_id    = azuread_application.buildingblock_deploy.client_id
    display_name = azuread_application.buildingblock_deploy.display_name
  } : null
  description = "Information about the created Azure AD application."
}

output "workload_identity_federation" {
  value = var.create_service_principal_name != null && var.workload_identity_federation != null ? {
    credential_id = azuread_application_federated_identity_credential.buildingblock_deploy.credential_id
    display_name  = azuread_application_federated_identity_credential.buildingblock_deploy.display_name
    issuer        = azuread_application_federated_identity_credential.buildingblock_deploy.issuer
    subject       = azuread_application_federated_identity_credential.buildingblock_deploy.subject
    audiences     = azuread_application_federated_identity_credential.buildingblock_deploy.audiences
  } : null
  description = "Information about the created workload identity federation credential."
}

output "application_password" {
  value = var.create_service_principal_name != null && var.workload_identity_federation == null ? {
    key_id       = azuread_application_password.buildingblock_deploy.key_id
    display_name = azuread_application_password.buildingblock_deploy.display_name
  } : null
  description = "Information about the created application password (excludes the actual password value for security)."
  sensitive   = true
}

output "scope" {
  value       = var.scope
  description = "The scope where the role definition and role assignments are applied."
}
