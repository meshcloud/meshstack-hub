output "project_id" {
  description = "ID of the created Azure DevOps project"
  value       = azuredevops_project.main.id
}

output "project_name" {
  description = "Name of the created Azure DevOps project"
  value       = azuredevops_project.main.name
}

output "project_url" {
  description = "URL of the created Azure DevOps project"
  value       = "${var.azure_devops_organization_url}/${azuredevops_project.main.name}"
}

output "project_visibility" {
  description = "Visibility of the project"
  value       = azuredevops_project.main.visibility
}

output "user_entitlements" {
  description = "Map of user entitlements created"
  value = {
    for email, user in azuredevops_user_entitlement.users : email => {
      descriptor   = user.descriptor
      license_type = user.account_license_type
    }
  }
}

output "group_memberships" {
  description = "Information about group memberships" 
  value = {
    readers = {
      group_descriptor = data.azuredevops_group.project_readers.descriptor
      members         = local.readers
    }
    contributors = {
      group_descriptor = data.azuredevops_group.project_contributors.descriptor
      members         = local.contributors
    }
    administrators = {
      group_descriptor = data.azuredevops_group.project_administrators.descriptor
      members         = local.administrators  
    }
  }
}

output "custom_groups" {
  description = "Information about custom groups created"
  value = var.create_custom_groups ? {
    readers = {
      id          = azuredevops_group.custom_readers[0].id
      descriptor  = azuredevops_group.custom_readers[0].descriptor
      display_name = azuredevops_group.custom_readers[0].display_name
    }
    contributors = {
      id          = azuredevops_group.custom_contributors[0].id
      descriptor  = azuredevops_group.custom_contributors[0].descriptor
      display_name = azuredevops_group.custom_contributors[0].display_name
    }
    administrators = {
      id          = azuredevops_group.custom_administrators[0].id
      descriptor  = azuredevops_group.custom_administrators[0].descriptor
      display_name = azuredevops_group.custom_administrators[0].display_name
    }
  } : {}
}

output "project_features" {
  description = "Enabled/disabled project features"
  value       = var.project_features
}