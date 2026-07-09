output "postgresql_server_id" {
  description = "The Azure resource ID of the PostgreSQL Flexible Server."
  value       = azurerm_postgresql_flexible_server.this.id
}

output "postgresql_server_name" {
  description = "The name of the PostgreSQL Flexible Server."
  value       = azurerm_postgresql_flexible_server.this.name
}

output "postgresql_fqdn" {
  description = "The fully qualified domain name of the PostgreSQL Flexible Server."
  value       = azurerm_postgresql_flexible_server.this.fqdn
}

output "postgresql_admin_username" {
  description = "The administrator username for the PostgreSQL Flexible Server."
  value       = azurerm_postgresql_flexible_server.this.administrator_login
}

output "postgresql_version" {
  description = "The PostgreSQL major version."
  value       = azurerm_postgresql_flexible_server.this.version
}

output "psql_admin_password" {
  description = "The administrator password for the PostgreSQL Flexible Server."
  value       = random_password.psql_admin_password.result
  sensitive   = true
}

output "resource_group_name" {
  description = "The name of the resource group in which the PostgreSQL Flexible Server is created."
  value       = azurerm_resource_group.postgresql.name
}
