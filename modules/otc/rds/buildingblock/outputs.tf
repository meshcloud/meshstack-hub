output "host" {
  value       = module.rds.db_private_ip
  description = "Private IP address the database answers on, reachable from the network's subnet."
}

output "port" {
  value       = local.ports[var.db_type]
  description = "Port the database listens on."
}

output "db_version" {
  value       = local.db_version
  description = "Engine version the database runs."
}

output "admin_username" {
  value       = module.rds.db_root_username
  description = "Name of the database's administrative user."
}

output "admin_password" {
  value       = module.rds.db_root_password
  sensitive   = true
  description = "Password of the database's administrative user."
}

output "summary" {
  description = "Markdown summary shown in meshPanel after the run."
  value       = <<-EOT
    # ${var.name}

    A ${var.high_availability ? "highly available (primary and standby)" : "single-node"} ${var.db_type} ${local.db_version} database in the network `${var.network_name}`.

    | | |
    |---|---|
    | Host | `${module.rds.db_private_ip}` |
    | Port | `${local.ports[var.db_type]}` |
    | Admin user | `${module.rds.db_root_username}` |

    The admin password is in this building block's outputs. The database has no public address:
    connect from a server or cluster in the subnet `${var.network_name}`, for example with
    `${local.connect_command}`.
  EOT
}
