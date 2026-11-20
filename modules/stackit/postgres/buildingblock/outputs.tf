locals {
  uri = "postgresql://${module.database.username}@${module.database.host}:${module.database.port}/${module.database.database}?sslmode=require"
}

output "instance_id" {
  value       = module.database.instance_id
  description = "ID of the PostgreSQL Flex instance the database is on."
}

output "host" {
  value       = module.database.host
  description = "DNS name of the instance's write endpoint."
}

output "port" {
  value       = module.database.port
  description = "TCP port of the instance's write endpoint."
}

output "database" {
  value       = module.database.database
  description = "Name of the database."
}

output "username" {
  value       = module.database.username
  description = "Name of the database user that owns the database."
}

output "jdbc_url" {
  value       = module.database.jdbc_url
  description = "JDBC URL of the database, without credentials."
}

output "uri" {
  value       = local.uri
  description = "Connection URI of the database, without the password."
}

output "vault_secret" {
  description = "`{path, secret_hash}` of the secret in Vault, where `secret_hash` changes with its content; `{}` without `output_to_vault`. Its key `kubernetes-secret` holds `host`, `port`, `database`, `username`, `password`, `jdbc_url` and `uri` with the password."
  value = {
    for key, value in {
      path        = local.vault_secret_path
      secret_hash = local.vault_secret_hash
    } : key => value if local.write_to_vault
  }
}

output "summary" {
  description = "Markdown summary shown in meshPanel after the run."
  value       = <<-EOT
    # PostgreSQL database `${module.database.database}`

    ${local.create_instance ? "On its own instance `${module.database.instance_name}`: PostgreSQL ${var.postgres_version} on ${var.replicas == 3 ? "3 nodes" : "a single node"} of flavor `${var.flavor}` with ${var.storage_size} GB `${var.storage_class}` storage, reachable from ${join(", ", [for cidr in coalesce(var.acl, []) : "`${cidr}`"])}." : "On the shared instance `${module.database.instance_name}`. Its other users cannot read or change the data in this database, but they can connect to it and see table names until you run `REVOKE CONNECT ON DATABASE ${module.database.database} FROM PUBLIC`."}

    | | |
    |---|---|
    | **Host** | `${module.database.host}` |
    | **Port** | `${module.database.port}` |
    | **Database** | `${module.database.database}` |
    | **Username** | `${module.database.username}` |
    | **JDBC URL** | `${module.database.jdbc_url}` |

    ```sh
    psql "${local.uri}"
    ```

    ${local.write_to_vault ? "The password is in the secret `${local.vault_secret_path}` of the secrets manager, next to the full connection URI." : "This definition hands out no password. Reset it for user `${module.database.username}` in the STACKIT portal to get one."}
  EOT
}
