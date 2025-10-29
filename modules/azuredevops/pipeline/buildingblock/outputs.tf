output "pipeline_id" {
  description = "ID of the created pipeline"
  value       = azuredevops_build_definition.main.id
}

output "pipeline_name" {
  description = "Name of the created pipeline"
  value       = azuredevops_build_definition.main.name
}

output "pipeline_revision" {
  description = "Revision number of the pipeline"
  value       = azuredevops_build_definition.main.revision
}

output "project_id" {
  description = "Project ID where the pipeline was created"
  value       = var.project_id
}

output "repository_id" {
  description = "Repository ID linked to the pipeline"
  value       = var.repository_id
}

output "yaml_path" {
  description = "Path to the YAML pipeline definition"
  value       = var.yaml_path
}
