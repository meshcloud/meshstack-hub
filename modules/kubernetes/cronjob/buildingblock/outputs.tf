output "cron_job_name" {
  description = "Name of the CronJob in the tenant namespace."
  value       = kubernetes_cron_job_v1.this.metadata[0].name
}

output "service_account_subject" {
  description = "Subject of the tokens of the job's Kubernetes service account, which a cloud's workload identity federation trusts."
  value       = "system:serviceaccount:${var.namespace}:${kubernetes_service_account_v1.this.metadata[0].name}"
}

output "summary" {
  description = "Markdown summary shown in meshPanel after the run."
  value       = <<-EOT
    # CronJob `${var.name}`

    Runs `${var.image}` on `${var.schedule}` in namespace `${var.namespace}`, as the Kubernetes service account
    `${var.name}`.%{if var.service_account_token != null} Its pods get a token with audience `${var.service_account_token.audience}` at
    `${var.service_account_token.mount_path}/token`.%{endif}

    Trigger a run right away and follow its logs:

    ```sh
    kubectl create job -n ${var.namespace} --from=cronjob/${var.name} ${var.name}-manual
    kubectl logs -n ${var.namespace} -l app=${var.name} --tail=200
    ```
  EOT
}
