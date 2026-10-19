# The T Cloud Public Network building block names the VPC and its subnet alike. When it has not run
# in this project, these lookups fail with "your query returned no results".
data "opentelekomcloud_vpc_v1" "network" {
  name = var.network_name
}

data "opentelekomcloud_vpc_subnet_v1" "network" {
  name   = var.network_name
  vpc_id = data.opentelekomcloud_vpc_v1.network.id
}

data "opentelekomcloud_rds_versions_v3" "this" {
  database_name = var.db_type

  lifecycle {
    postcondition {
      condition     = var.db_version == null || contains(self.versions, coalesce(var.db_version, "-"))
      error_message = "${var.db_type} ${coalesce(var.db_version, "-")} is not offered here. Available versions: ${join(", ", self.versions)}."
    }
  }
}

locals {
  available_versions = data.opentelekomcloud_rds_versions_v3.this.versions

  # SQL Server comes in several editions per release; Standard is the sensible default.
  standard_editions  = [for v in local.available_versions : v if endswith(v, "_SE")]
  candidate_versions = var.db_type == "SQLServer" && length(local.standard_editions) > 0 ? local.standard_editions : local.available_versions

  # The try swallows a version without a leading number, which then ranks as oldest.
  version_numbers = { for v in local.candidate_versions : v => try(tonumber(regex("^[0-9]+(?:\\.[0-9]+)?", v)), 0) }
  newest_version  = [for v, n in local.version_numbers : v if n == max(values(local.version_numbers)...)][0]
  db_version      = coalesce(var.db_version, local.newest_version)

  sizes = {
    small  = { cpus = "2", memory = 4 }
    medium = { cpus = "4", memory = 8 }
    large  = { cpus = "8", memory = 16 }
  }

  ports = {
    MySQL      = 3306
    PostgreSQL = 5432
    SQLServer  = 1433
  }
}

# Creates its own security group, which admits the subnet's CIDR on the engine's port, and a KMS
# key that encrypts the volumes.
module "rds" {
  source = "git::https://github.com/iits-consulting/terraform-opentelekomcloud-rds.git?ref=v7.7.0"

  name      = var.name
  vpc_id    = data.opentelekomcloud_vpc_v1.network.id
  subnet_id = data.opentelekomcloud_vpc_subnet_v1.network.id

  db_type              = var.db_type
  db_version           = local.db_version
  db_cpus              = local.sizes[var.size].cpus
  db_memory            = local.sizes[var.size].memory
  db_size              = var.storage_size
  db_high_availability = var.high_availability
}

locals {
  connect_command = {
    MySQL      = "mysql -h ${module.rds.db_private_ip} -P 3306 -u ${module.rds.db_root_username} -p"
    PostgreSQL = "psql -h ${module.rds.db_private_ip} -p 5432 -U ${module.rds.db_root_username} -d postgres"
    SQLServer  = "sqlcmd -S ${module.rds.db_private_ip},1433 -U ${module.rds.db_root_username}"
  }[var.db_type]
}
