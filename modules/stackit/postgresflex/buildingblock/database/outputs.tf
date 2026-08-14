output "instance_id" {
  value       = local.instance_id
  description = "UUID of the PostgreSQL Flex instance. In database-only mode this is the `existing_instance_id` the caller passed in."
}

output "host" {
  value       = local.host
  description = "DNS name of the instance's write endpoint."
}

output "port" {
  value       = local.port
  description = "TCP port of the instance's write endpoint."
}

output "database_name" {
  value       = stackit_postgresflex_database.this.name
  description = "Name of the database created on the instance."
}

output "username" {
  value       = stackit_postgresflex_user.this.username
  description = "Name of the database user that owns the database."
}

output "password" {
  value       = stackit_postgresflex_user.this.password
  description = "Password of the database user. STACKIT generates it and shows it only once."
  sensitive   = true
}

output "connection_string" {
  value       = local.connection_string
  description = "Ready-to-use libpq connection string including the password. Applications such as LiteLLM and Langfuse take this as their DATABASE_URL."
  sensitive   = true
}

output "direct_connection_string" {
  value       = local.connection_string
  description = "Connection string that addresses the instance's write endpoint directly, never a connection pooler placed in front of it. Langfuse takes it as DIRECT_URL and runs its Prisma migrations over it. This module places no pooler in front of the instance, so the value equals `connection_string` today, and the separate output gives a caller that later adds one a stable name to wire DIRECT_URL to."
  sensitive   = true
}

output "summary" {
  description = "Summary with instance details and database credentials."
  sensitive   = true
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    instance_name = local.instance_name
    instance_id   = local.instance_id
    host          = local.host
    port          = local.port
    database_name = stackit_postgresflex_database.this.name
    username      = stackit_postgresflex_user.this.username
    password      = stackit_postgresflex_user.this.password
    version       = local.instance_version
    acl           = join(", ", local.instance_acl)
  })
}
