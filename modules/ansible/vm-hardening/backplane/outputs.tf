output "workflow" {
  description = "Workflow file meshStack dispatches."
  value       = "ansible-vm-hardening.yml"

  # The definition must not point meshStack at the workflow before the playbook it runs is committed.
  depends_on = [github_repository_file.this]
}

output "branch" {
  description = "Branch the workflow is dispatched on."
  value       = var.github_branch
  depends_on  = [github_repository_file.this]
}
