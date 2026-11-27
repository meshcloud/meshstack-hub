output "instance_id" {
  value       = local.create_instance ? stackit_postgresflex_instance.this.instance_id : var.existing_instance_id
  description = "ID of the PostgreSQL Flex instance: the one created, or the one the database is on."
}

output "host" {
  value       = local.create_instance ? stackit_postgresflex_instance.this.connection_info.write.host : module.database.host
  description = "DNS name of the instance's write endpoint."
}

output "port" {
  value       = local.create_instance ? stackit_postgresflex_instance.this.connection_info.write.port : module.database.port
  description = "TCP port of the instance's write endpoint."
}

output "database" {
  value       = local.create_instance ? null : module.database.database
  description = "Name of the database. Only with `existing_instance_id`."
}

output "username" {
  value       = local.create_instance ? null : module.database.username
  description = "Name of the database user that owns the database. Only with `existing_instance_id`."
}

output "jdbc_url" {
  value       = local.create_instance ? null : module.database.jdbc_url
  description = "JDBC URL of the database, without credentials. Only with `existing_instance_id`."
}

output "uri" {
  value       = local.create_instance ? null : module.database.uri
  description = "Connection URI of the database, without the password. Only with `existing_instance_id`."
}

output "summary" {
  description = "Markdown summary shown in meshPanel after the run."
  value       = local.create_instance ? local.instance_summary : local.database_summary
}

locals {
  instance_summary = !local.create_instance ? null : <<-EOT
    PostgreSQL instance `${var.instance_name}` runs PostgreSQL ${var.postgres_version} on ${var.replicas == 3 ? "3 nodes" : "a single node"} of flavor `${var.flavor}` with ${var.storage_size} GB `${var.storage_class}` storage.

    | | |
    |---|---|
    | Instance ID | `${stackit_postgresflex_instance.this.instance_id}` |
    | Host | `${stackit_postgresflex_instance.this.connection_info.write.host}` |
    | Port | `${stackit_postgresflex_instance.this.connection_info.write.port}` |
    | Allowed sources | ${join(", ", [for cidr in var.acl : "`${cidr}`"])} |

    This building block creates no database. To add databases, publish the database definition of this module with `stackit_existing_instance_id` set to the instance ID above; each of its building blocks creates one database and its owner user here.
  EOT

  database_summary = local.create_instance ? null : <<-EOT
    PostgreSQL database `${module.database.database}` is on the shared instance `${module.database.instance_name}`.

    | | |
    |---|---|
    | Host | `${module.database.host}` |
    | Port | `${module.database.port}` |
    | Database | `${module.database.database}` |
    | Username | `${module.database.username}` |
    | JDBC URL | `${module.database.jdbc_url}` |

    This definition hands out no password: it is the base for connector definitions, which pass the credentials on, for example into a Kubernetes Secret. Without a connector, reset the password of user `${module.database.username}` in the STACKIT portal.

    This definition alone does not close the database to other users of the instance: they cannot read or change its data, but they can connect to it and see table names. A connector completes the isolation with `REVOKE ALL ON DATABASE ${module.database.database} FROM PUBLIC`, run from a network the instance accepts.
  EOT
}
