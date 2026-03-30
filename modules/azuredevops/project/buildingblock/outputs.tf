output "project_id" {
  description = "ID of the created Azure DevOps project"
  value       = azuredevops_project.main.id
}

output "project_name" {
  description = "Name of the created Azure DevOps project"
  value       = azuredevops_project.main.name
}

output "project_visibility" {
  description = "Visibility of the project"
  value       = azuredevops_project.main.visibility
}

output "user_assignments" {
  description = "Map of users and their assigned roles"
  value = {
    for user in var.users : user.email => {
      meshIdentifier = user.meshIdentifier
      username       = user.username
      firstName      = user.firstName
      lastName       = user.lastName
      euid           = user.euid
      roles          = user.roles
    }
  }
}

output "group_memberships" {
  description = "Information about group memberships"
  value = {
    readers = {
      group_descriptor = data.azuredevops_group.project_readers.descriptor
      members          = local.readers
    }
    contributors = {
      group_descriptor = data.azuredevops_group.project_contributors.descriptor
      members          = local.contributors
    }
    administrators = {
      group_descriptor = data.azuredevops_group.project_administrators.descriptor
      members          = local.administrators
    }
  }
}

output "project_features" {
  description = "Enabled/disabled project features"
  value       = var.project_features
}

output "repository_id" {
  description = "ID of the created repository"
  value       = azuredevops_git_repository.main.id
}

output "repository_name" {
  description = "Name of the created repository"
  value       = azuredevops_git_repository.main.name
}

output "repository_url" {
  description = "URL of the created repository"
  value       = azuredevops_git_repository.main.url
}

output "ssh_url" {
  description = "SSH URL of the repository"
  value       = azuredevops_git_repository.main.ssh_url
}

output "web_url" {
  description = "Web URL of the repository"
  value       = azuredevops_git_repository.main.web_url
}

output "default_branch" {
  description = "Default branch of the repository"
  value       = azuredevops_git_repository.main.default_branch
}

output "branch_policies_enabled" {
  description = "Whether branch policies are enabled"
  value       = var.enable_branch_policies
}
