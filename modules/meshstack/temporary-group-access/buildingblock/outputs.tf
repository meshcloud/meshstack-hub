output "expires_at" {
  description = "RFC 3339 timestamp after which the access ends. The sweeper of the backplane deletes this building block on its first run after it."
  value       = local.expires_at
}

output "expiry_date" {
  description = "Date (YYYY-MM-DD) set as the expiry date of the group binding."
  value       = local.expiry_date
}

output "summary" {
  description = "Markdown summary shown in meshPanel after the run."
  value = (local.expired ? <<-EOT
    # Access of `${var.group_name}` has ended

    The group **`${var.group_name}`** no longer has the role **${var.workspace_role_name}** on
    workspace **`${var.workspace_identifier}`**; it expired on **${local.expiry_date}**. This building
    block is deleted automatically within a day.
  EOT
    : <<-EOT
    # Temporary access for `${var.group_name}`

    Members of the group **`${var.group_name}`** have the role **${var.workspace_role_name}** on
    workspace **`${var.workspace_identifier}`** until **${local.expiry_date}**. After that date the
    access ends, and this building block is deleted automatically within a day.
  EOT
  )
}
