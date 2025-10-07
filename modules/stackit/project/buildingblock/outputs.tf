output "project_id" {
  value       = stackit_resourcemanager_project.project.project_id
  description = "The UUID of the created StackIt project."
}

output "container_id" {
  value       = stackit_resourcemanager_project.project.container_id
  description = "The user-friendly container ID of the created StackIt project."
}

output "project_name" {
  value       = stackit_resourcemanager_project.project.name
  description = "The name of the created StackIt project."
}

output "service_account_email" {
  value       = var.create_service_account ? stackit_service_account.automation[0].email : null
  description = "The email of the created service account (if created)."
}

output "project_url" {
  value       = "https://portal.stackit.cloud/projects/${stackit_resourcemanager_project.project.project_id}"
  description = "The deep link URL to access the project in the StackIt portal."
}