output "summary" {
  description = "Markdown summary shown in meshPanel after the run."
  value       = <<-EOT
    # Custom Platform Metering

    Workspaces can now order **Platform Metering** in `${var.workspace}`. Each order creates the project
    `${var.metering_project.name}` with a namespace on `${var.kubernetes.platform_identifier}` and one metering job per
    selected cloud, running on `${var.metering.schedule}`.

    | Definition | Reports to |
    |---|---|
    %{~if var.stackit_enabled}
    | STACKIT Metering | `${var.stackit.platform_identifier}` |
    %{~endif}
    %{~if var.tcloud_enabled}
    | T Cloud Public Metering | `${var.tcloud.platform_identifier}` |
    %{~endif}
    | Kubernetes Service Account | namespaces on `${local.kubeconfig_cluster.name}` |
    %{if var.tcloud_enabled}
    The Financial Dashboard API key expires after at most 90 days. Enter a new one in this building block and run
    it again before then, and the metering jobs pick it up on their next building block run.
    %{endif}
  EOT
}
