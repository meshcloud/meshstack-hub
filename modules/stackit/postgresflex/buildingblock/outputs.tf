output "instance_id" {
  value       = stackit_postgresflex_instance.this.instance_id
  description = "UUID of the PostgreSQL Flex instance."
}

output "host" {
  value       = stackit_postgresflex_instance.this.connection_info.write.host
  description = "DNS name of the instance's write endpoint."
}

output "port" {
  value       = stackit_postgresflex_instance.this.connection_info.write.port
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
  value       = "postgresql://${stackit_postgresflex_user.this.username}:${urlencode(stackit_postgresflex_user.this.password)}@${stackit_postgresflex_instance.this.connection_info.write.host}:${stackit_postgresflex_instance.this.connection_info.write.port}/${stackit_postgresflex_database.this.name}?sslmode=require"
  description = "Ready-to-use libpq connection string including the password. Applications such as LiteLLM and Langfuse take this as their DATABASE_URL."
  sensitive   = true
}

output "summary" {
  description = "Summary with instance details and database credentials."
  sensitive   = true
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    instance_name = stackit_postgresflex_instance.this.name
    instance_id   = stackit_postgresflex_instance.this.instance_id
    host          = stackit_postgresflex_instance.this.connection_info.write.host
    port          = stackit_postgresflex_instance.this.connection_info.write.port
    database_name = stackit_postgresflex_database.this.name
    username      = stackit_postgresflex_user.this.username
    password      = stackit_postgresflex_user.this.password
    version       = stackit_postgresflex_instance.this.version
    acl           = join(", ", local.acl)
  })
}
