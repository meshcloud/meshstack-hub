output "repository_full_name" {
  description = "Repository full name in owner/repo format for meshStack github_workflows implementation.repository."
  value       = "${var.github_owner}/${var.github_repository_name}"
}

output "branch" {
  description = "Configured branch for workflow dispatch."
  value       = var.github_branch
  depends_on  = [github_repository_file.workflow]
}

output "apply_workflow" {
  description = "Configured apply workflow filename."
  value       = var.github_apply_workflow
  depends_on  = [github_repository_file.workflow]
}

output "apply_workflow_async" {
  description = "Configured async apply workflow filename."
  value       = var.github_apply_workflow_async
  depends_on  = [github_repository_file.workflow]
}

output "destroy_workflow" {
  description = "Configured destroy workflow filename."
  value       = var.github_destroy_workflow
  depends_on  = [github_repository_file.workflow]
}

output "destroy_workflow_async" {
  description = "Configured async destroy workflow filename."
  value       = var.github_destroy_workflow_async
  depends_on  = [github_repository_file.workflow]
}
