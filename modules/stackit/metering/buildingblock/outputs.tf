output "cron_job_name" {
  description = "Name of the metering CronJob in the tenant namespace."
  value       = kubernetes_cron_job_v1.this.metadata[0].name
}

output "summary" {
  description = "Markdown summary shown in meshPanel after the run."
  value       = <<-EOT
    # STACKIT metering for `${var.platform_identifier}`

    CronJob **`${local.name}`** in namespace `${var.namespace}` runs on `${var.schedule}`. Each run reads the costs
    of the STACKIT organization `${var.stackit_organization_id}` for the current month (and the last month during
    the first five days) and submits them as usage reports to ${var.meshstack_meshfed_url}.

    It acts as `${var.stackit_metering_service_account_email}` through workload identity federation with the token of
    its Kubernetes service account `${local.name}`, so there is no STACKIT key to rotate.

    Trigger a run right away and follow its logs:

    ```sh
    kubectl create job -n ${var.namespace} --from=cronjob/${local.name} ${local.name}-manual
    kubectl logs -n ${var.namespace} -l app=${local.name} --tail=200
    ```
  EOT
}
