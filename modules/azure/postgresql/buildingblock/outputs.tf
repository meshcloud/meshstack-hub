output "postgresql_server_name" {
  description = "The name of the PostgreSQL Flexible Server."
  value       = azurerm_postgresql_flexible_server.this.name
}

output "postgresql_fqdn" {
  description = "The fully qualified domain name of the PostgreSQL Flexible Server."
  value       = azurerm_postgresql_flexible_server.this.fqdn
}

output "postgresql_admin_username" {
  description = "The administrator user of the PostgreSQL Flexible Server."
  value       = azurerm_postgresql_flexible_server.this.administrator_login
}

output "postgresql_version" {
  description = "The PostgreSQL major version."
  value       = azurerm_postgresql_flexible_server.this.version
}

output "resource_group_name" {
  description = "The name of the resource group that holds the server."
  value       = azurerm_resource_group.this.name
}

output "postgresql_portal_url" {
  description = "Azure Portal URL of the PostgreSQL Flexible Server."
  value       = local.portal_url
}

output "summary" {
  description = "Markdown summary shown in meshPanel after the run."
  value       = <<-EOT
    # PostgreSQL Flexible Server `${azurerm_postgresql_flexible_server.this.name}`

    PostgreSQL ${azurerm_postgresql_flexible_server.this.version} on `${azurerm_postgresql_flexible_server.this.sku_name}` with ${azurerm_postgresql_flexible_server.this.storage_mb / 1024} GB storage.

    | | |
    |---|---|
    | Host | `${azurerm_postgresql_flexible_server.this.fqdn}` |
    | Port | `5432` |
    | Administrator | `${azurerm_postgresql_flexible_server.this.administrator_login}` |
    | Resource group | `${azurerm_resource_group.this.name}` |
    | Public network access | ${var.public_network_access_enabled ? "Enabled, add firewall rules to let clients in" : "Disabled"} |

    The building block does not hand out the administrator password. Set a new one with *Reset password* on the server's overview page in the [Azure Portal](${local.portal_url}) before you connect.
  EOT
}
