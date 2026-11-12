output "summary" {
  description = "Markdown summary shown in meshPanel after the run."
  value       = <<-EOT
    # ${var.project_display_name}

    Project **`${meshstack_project.this.metadata.name}`** holds the metering namespace `${meshstack_tenant.this.spec.platform_tenant_id}`.
    %{~if length(local.clouds) == 0}

    No cloud is metered yet. Edit this building block and select the clouds whose costs meshStack should collect.
    %{~else}

    | Cloud | Schedule |
    |---|---|
    %{~for cloud in sort(keys(local.clouds))}
    | ${cloud} | `${var.schedule}` |
    %{~endfor}

    Each cloud runs as its own CronJob in the namespace and submits the costs of the current month as usage reports.
    Select another cloud on this building block to add its metering, deselect one to remove it.
    %{~endif}
  EOT
}
