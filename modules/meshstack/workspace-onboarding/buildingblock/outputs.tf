locals {
  # Only resolvable once the STACKIT Project building block inside the tenant has replicated — and
  # never, once the tenant has been destroyed because the workspace expired.
  stackit_project_id = try(meshstack_tenant.this.spec.platform_tenant_id, null)
}

# These identifiers are derived from inputs rather than read off the resources themselves, so they
# stay stable and non-null even on a run that destroys everything because the workspace has expired —
# every declared output has to be produced on every run, expired or not.

output "workspace_identifier" {
  description = "Identifier of the workspace — of the one that existed, if the run destroyed it because its expiry date had passed."
  value       = var.workspace_identifier
}

output "payment_method_identifier" {
  description = "Identifier of the payment method — of the one that existed, if the run destroyed it because the workspace's expiry date had passed."
  value       = local.payment_method_identifier
}

output "project_identifier" {
  description = "Identifier of the project — of the one that existed, if the run destroyed it because the workspace's expiry date had passed."
  value       = var.project_identifier
}

output "stackit_project_url" {
  description = "Deep link to the STACKIT project, once the tenant has replicated. Reports the expiry once the workspace's expiry date has passed and everything has been destroyed."
  value = (local.expired
    ? "n/a — destroyed, the workspace's expiry date (${var.workspace_expiry_date}) has passed"
    : (local.stackit_project_id == null
      ? "https://portal.stackit.cloud"
      : "https://portal.stackit.cloud/projects/${local.stackit_project_id}"
    )
  )
}

output "summary" {
  description = "Summary of what this building block created, or of the fact that it destroyed everything because the workspace's expiry date passed."
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    expired = local.expired

    workspace_display_name = var.workspace_display_name
    workspace_identifier   = var.workspace_identifier
    workspace_expiry_date  = var.workspace_expiry_date
    workspace_owner        = var.workspace_owner_username

    payment_method_identifier = local.payment_method_identifier

    project_display_name = var.project_display_name
    project_identifier   = var.project_identifier
    project_admin        = var.project_admin_username

    stackit_project = (local.stackit_project_id == null
      ? "provisioning — the tenant has not replicated yet"
      : "[Open in STACKIT Portal](https://portal.stackit.cloud/projects/${local.stackit_project_id}) (`${local.stackit_project_id}`)"
    )
  })
}
