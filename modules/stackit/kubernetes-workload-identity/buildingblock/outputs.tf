output "service_account_email" {
  description = "STACKIT service account the Kubernetes workload acts as, e.g. for `STACKIT_SERVICE_ACCOUNT_EMAIL`."
  value       = var.workload_service_account_email
}

output "summary" {
  description = "Markdown summary shown in meshPanel after the run."
  value       = <<-EOT
    # STACKIT workload identity for `${var.kubernetes_service_account_name}`

    Tokens of the Kubernetes service account `${local.subject}` with audience `${var.audience}` act as the STACKIT
    service account `${var.workload_service_account_email}`. There is no STACKIT key.

    Give the workload a projected token of that service account with this audience, and these environment variables:

    ```sh
    STACKIT_SERVICE_ACCOUNT_EMAIL=${var.workload_service_account_email}
    STACKIT_FEDERATED_TOKEN_FILE=<path of the projected token>
    ```
  EOT
}
