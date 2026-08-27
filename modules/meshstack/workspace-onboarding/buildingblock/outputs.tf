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
  description = "Identifier of the project — of the one that existed, if the run destroyed it because the workspace's TTL had elapsed."
  value       = var.project_identifier
}

output "workspace_expiry_date" {
  description = "Date (YYYY-MM-DD) this building block computed from its creation date plus workspace_ttl_days — the date the workspace, and everything else this block created, are destroyed on the next run."
  value       = local.expiry_date
}
