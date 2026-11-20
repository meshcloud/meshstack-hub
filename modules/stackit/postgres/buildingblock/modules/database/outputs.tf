output "instance_name" {
  value       = data.stackit_postgresflex_instance.this.name
  description = "Name of the instance the database is on."
}

output "host" {
  value       = local.host
  description = "DNS name of the instance's write endpoint."
}

output "port" {
  value       = local.port
  description = "TCP port of the instance's write endpoint."
}

output "database" {
  value       = stackit_postgresflex_database.this.name
  description = "Name of the database."
}

output "username" {
  value       = stackit_postgresflex_user.this.username
  description = "Name of the database user that owns the database."
}

output "password" {
  value       = stackit_postgresflex_user.this.password
  sensitive   = true
  description = "Password of the database user, for a module that wraps this one. A building block root never outputs it."
}

output "jdbc_url" {
  value       = "jdbc:postgresql://${local.host}:${local.port}/${stackit_postgresflex_database.this.name}?sslmode=require"
  description = "JDBC URL of the database, without credentials."
}

output "uri" {
  value       = "postgresql://${stackit_postgresflex_user.this.username}@${local.host}:${local.port}/${stackit_postgresflex_database.this.name}?sslmode=require"
  description = "Connection URI of the database, without the password."
}
