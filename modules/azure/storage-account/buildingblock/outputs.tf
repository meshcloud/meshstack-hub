output "storage_account_id" {
  value = azurerm_storage_account.storage_account.id
}

output "storage_account_name" {
  value = azurerm_storage_account.storage_account.name
}

output "storage_account_resource_group" {
  value = azurerm_resource_group.storage_account_rg.name
}

output "storage_account_url" {
  value = local.portal_url
}

output "tags" {
  value = azurerm_storage_account.storage_account.tags
}

output "network_default_action" {
  # `try` because the network_rules block only exists when restrict_network_access is true; Azure's
  # own default applies otherwise.
  value = try(azurerm_storage_account.storage_account.network_rules[0].default_action, "Allow")
}

output "blob_soft_delete_retention_days" {
  description = "The blob soft-delete retention applied, in days. 0 when soft delete is disabled."
  # meshStack's output validation fails a run that reports null for a declared output, so
  # "disabled" (null input) is reported as 0 instead.
  value = coalesce(var.blob_soft_delete_retention_days, 0)
}

output "summary" {
  description = "Markdown summary output of the building block"
  value       = <<-EOT
    # Azure Storage Account

    Your Azure Storage Account was successfully created!

    ## Details

    - **Name**: ${azurerm_storage_account.storage_account.name}
    - **Resource group**: ${azurerm_resource_group.storage_account_rg.name}
    - **Location**: ${azurerm_storage_account.storage_account.location}
    - **Primary blob endpoint**: `${azurerm_storage_account.storage_account.primary_blob_endpoint}`
    - **Blob soft delete retention**: ${var.blob_soft_delete_retention_days != null ? "${var.blob_soft_delete_retention_days} days" : "Disabled"}
    - **Network access**: ${try(azurerm_storage_account.storage_account.network_rules[0].default_action, "Allow") == "Deny" ? "Restricted" : "Allowed from any network"}
    - [Open in Azure Portal](${local.portal_url})
  EOT
}
