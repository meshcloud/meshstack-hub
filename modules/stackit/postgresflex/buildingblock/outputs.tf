output "instance_id" {
  value       = module.database.instance_id
  description = "UUID of the PostgreSQL Flex instance. In database-only mode this is the `existing_instance_id` the caller passed in."
}

output "host" {
  value       = module.database.host
  description = "DNS name of the instance's write endpoint."
}

output "port" {
  value       = module.database.port
  description = "TCP port of the instance's write endpoint."
}

output "database_name" {
  value       = module.database.database_name
  description = "Name of the database created on the instance."
}

output "username" {
  value       = module.database.username
  description = "Name of the database user that owns the database."
}

output "password" {
  value       = module.database.password
  description = "Password of the database user. STACKIT generates it and shows it only once."
  sensitive   = true
}

output "connection_string" {
  value       = module.database.connection_string
  description = "Ready-to-use libpq connection string including the password. Applications such as LiteLLM and Langfuse take this as their DATABASE_URL."
  sensitive   = true
}

output "direct_connection_string" {
  value       = module.database.direct_connection_string
  description = "Connection string that addresses the instance's write endpoint directly, never a connection pooler placed in front of it. Langfuse takes it as DIRECT_URL and runs its Prisma migrations over it. This module places no pooler in front of the instance, so the value equals `connection_string` today, and the separate output gives a caller that later adds one a stable name to wire DIRECT_URL to."
  sensitive   = true
}

output "summary" {
  value       = module.database.summary
  description = "Summary with instance details and database credentials."
  sensitive   = true
}
