output "cron_job_name" {
  description = "Name of the metering CronJob in the tenant namespace."
  value       = kubernetes_cron_job_v1.this.metadata[0].name
}

output "summary" {
  description = "Markdown summary shown in meshPanel after the run."
  value       = <<-EOT
    # T Cloud Public metering for `${var.platform_identifier}`

    CronJob **`${local.name}`** in namespace `${var.namespace}` runs on `${var.schedule}`. Each run reads the
    consumption of %{if length(var.tcloud_contract_ids) > 0}the contracts `${join("`, `", var.tcloud_contract_ids)}`%{else}every contract the API key sees%{endif}
    from the T Cloud Financial Dashboard for the current month (and the last month during the first five days) and
    submits it as usage reports to ${var.meshstack_meshfed_url}.

    The Financial Dashboard API key expires after at most 90 days. When runs fail with HTTP 401
    `Invalid or expired user api token`, ask the platform team for a new key; it reaches this CronJob on the next
    run of this building block.

    Trigger a run right away and follow its logs:

    ```sh
    kubectl create job -n ${var.namespace} --from=cronjob/${local.name} ${local.name}-manual
    kubectl logs -n ${var.namespace} -l app=${local.name} --tail=200
    ```
  EOT
}
