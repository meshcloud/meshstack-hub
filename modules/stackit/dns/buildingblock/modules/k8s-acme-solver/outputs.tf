output "service_account_email" {
  description = "Email of the service account that writes the challenge records."
  value       = stackit_service_account.this.email
}

output "solver" {
  description = "The `dns01` block of a cert-manager ACME solver for zones in the project."
  value = {
    webhook = {
      groupName  = local.group_name
      solverName = "stackit"
      config     = { projectId = var.project_id }
    }
  }

  depends_on = [helm_release.webhook]
}
