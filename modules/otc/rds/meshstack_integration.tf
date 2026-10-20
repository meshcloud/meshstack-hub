variable "bbd_display_name" {
  type        = string
  default     = null
  description = "Overrides the name of the marketplace entry application teams see in the catalog."
}

variable "bbd_description" {
  type        = string
  default     = null
  description = "Overrides the one-line description shown next to the marketplace entry."
}

variable "bbd_readme" {
  type        = string
  default     = null
  description = "Overrides the markdown readme shown in the marketplace before ordering."
}

variable "otc_domain_name" {
  type        = string
  description = "T Cloud Public domain (account) name, e.g. `OTC-EU-DE-00000000001000000000`."
}

variable "otc_region" {
  type        = string
  default     = "eu-de"
  description = "T Cloud Public region the application teams' projects live in."
}

variable "otc_auth_url" {
  type        = string
  default     = "https://iam.eu-de.otc.t-systems.com/v3"
  description = "IAM endpoint the building block authenticates against."
}

variable "workload_identity_name" {
  type        = string
  default     = "meshstack-rds"
  description = "Name of the identity provider and IAM group the building block signs in through. Unique across the domain."
}

variable "otc_platform_type" {
  type        = string
  default     = "OTC"
  description = "Name of the custom meshStack platform type the application teams' tenants live on."
}

variable "building_block_runner_uuid" {
  type        = string
  default     = null
  description = "Runs this building block on the given meshStack building block runner instead of the shared one meshStack hosts."
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    tags                        = optional(map(list(string)), {})
  })
  description = "Shared meshStack context. Tags are optional and propagated to building block definition metadata."
}

variable "hub" {
  type = object({
    git_ref   = optional(string, "main")
    bbd_draft = optional(bool, true)
  })
  const = true
  default = {
    git_ref   = "main"
    bbd_draft = true
  }
  description = <<-EOT
  `git_ref`: Hub release reference. Set to a tag (e.g. 'v1.2.3') or branch or commit sha of the meshstack-hub repo.
  `bbd_draft`: If true, the building block definition version is kept in draft mode.
  EOT
}

# Runs sign in through workload identity federation, so the definition carries no access key. This
# module's own provider credentials only set up the identity provider and its group.
module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/otc/rds/backplane?ref=${var.hub.git_ref}"

  name = var.workload_identity_name
  workload_identity_federation = {
    issuer   = meshstack_building_block_definition.this.version_latest.workload_identity_federation.issuer
    subject  = meshstack_building_block_definition.this.version_latest.workload_identity_federation.subject
    audience = meshstack_building_block_definition.this.version_latest.workload_identity_federation.gcp.audience
  }
}

output "building_block_definition" {
  description = "BBD is consumed in building block compositions."
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name        = coalesce(var.bbd_display_name, "T Cloud Public Relational Database")
    symbol              = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/otc/rds/buildingblock/logo.png"
    description         = coalesce(var.bbd_description, "Provisions a managed MySQL, PostgreSQL or SQL Server database in your T Cloud Public project, encrypted and reachable only from your network.")
    support_url         = "https://console.otc.t-systems.com"
    target_type         = "TENANT_LEVEL"
    run_transparency    = true
    supported_platforms = [{ name = var.otc_platform_type }]

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
    This building block creates a managed relational database (RDS) in your T Cloud Public project:
    MySQL, PostgreSQL or SQL Server, with encrypted storage, automated backups and an optional
    standby node in a second availability zone.

    The database is placed in your project's network and has no public address. Order the
    **T Cloud Public Network** building block on the project first.

    ## 🎯 When to use it

    Use this building block when you:
    - need a relational database for an application that runs in your T Cloud Public project
    - want backups, encryption and failover handled by the platform instead of running a database
      server yourself

    ## 💡 Usage examples

    **Example 1: A PostgreSQL database for a web application**
    A team orders a small PostgreSQL database for its service running on a cluster in the same
    network. The building block outputs the host, port and admin password the service connects with.

    **Example 2: A highly available database for production**
    A team running a customer-facing system orders a medium MySQL database with high availability,
    so a standby node in a second availability zone takes over if the primary fails.

    ## 📊 Shared Responsibility

    | Responsibility | Platform Team | Application Team |
    |---|:---:|:---:|
    | Provide the project, network and credentials the database is created with | ✅ | ❌ |
    | Run the database service, its backups and failover | ✅ | ❌ |
    | Encrypt the database volumes | ✅ | ❌ |
    | Choose engine, version, size and availability | ❌ | ✅ |
    | Create application users and schemas, and keep the admin password safe | ❌ | ✅ |
    | Restore data from backups when needed | ❌ | ✅ |
    EOT
    ))
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"
    runner_ref = var.building_block_runner_uuid == null ? null : {
      kind = "meshBuildingBlockRunner"
      uuid = var.building_block_runner_uuid
    }

    implementation = {
      terraform = {
        terraform_version              = "1.12.5"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/otc/rds/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
        pre_run_script                 = file("${path.module}/../workload-identity/prerun.sh")
      }
    }

    inputs = {
      name = {
        display_name    = "Name"
        description     = "Name of the database instance, unique within the project: 4 to 64 letters, digits, hyphens or underscores, starting with a letter."
        type            = "STRING"
        assignment_type = "USER_INPUT"
      }

      db_type = {
        display_name      = "Engine"
        description       = "Database engine."
        type              = "SINGLE_SELECT"
        assignment_type   = "USER_INPUT"
        selectable_values = ["PostgreSQL", "MySQL", "SQLServer"]
        default_value     = jsonencode("PostgreSQL")
      }

      db_version = {
        display_name    = "Engine Version"
        description     = "For example 16 for PostgreSQL, 8.0 for MySQL or 2022_SE for SQL Server. Leave it empty for the newest version, for SQL Server its Standard Edition."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        is_optional     = true
      }

      size = {
        display_name           = "Size"
        description            = "Compute of each database node: small (2 vCPUs, 4 GB), medium (4 vCPUs, 8 GB) or large (8 vCPUs, 16 GB)."
        type                   = "SINGLE_SELECT"
        assignment_type        = "USER_INPUT"
        selectable_values      = ["small", "medium", "large"]
        default_value          = jsonencode("small")
        updateable_by_consumer = true
      }

      storage_size = {
        display_name           = "Storage (GB)"
        description            = "Storage of the database in GB, between 40 and 4000. It can grow later, but not shrink."
        type                   = "INTEGER"
        assignment_type        = "USER_INPUT"
        default_value          = jsonencode(100)
        updateable_by_consumer = true
      }

      high_availability = {
        display_name    = "High Availability"
        description     = "Run a standby node in a second availability zone that takes over if the primary fails."
        type            = "BOOLEAN"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(false)
      }

      network_name = {
        display_name    = "Network"
        description     = "Name of the network the T Cloud Public Network building block created in this project."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("app")
      }

      project_id = {
        display_name    = "Project ID"
        description     = "Project the database is created in."
        type            = "STRING"
        assignment_type = "PLATFORM_TENANT_ID"
      }

      region = {
        display_name    = "Region"
        description     = "Region of the project."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.otc_region)
      }

      OS_AUTH_URL = {
        display_name    = "OTC Auth URL"
        description     = "IAM endpoint the provider authenticates against."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(var.otc_auth_url)
      }

      OS_DOMAIN_NAME = {
        display_name    = "OTC Domain Name"
        description     = "T Cloud Public domain the building block acts in."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(var.otc_domain_name)
      }

      OTC_IDENTITY_PROVIDER = {
        display_name    = "OTC Identity Provider"
        description     = "Identity provider the pre-run script exchanges the run token at."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(var.workload_identity_name)
      }
    }

    outputs = {
      host = {
        display_name    = "Host"
        type            = "STRING"
        assignment_type = "NONE"
      }

      port = {
        display_name    = "Port"
        type            = "INTEGER"
        assignment_type = "NONE"
      }

      db_version = {
        display_name    = "Engine Version"
        type            = "STRING"
        assignment_type = "NONE"
      }

      admin_username = {
        display_name    = "Admin User"
        type            = "STRING"
        assignment_type = "NONE"
      }

      admin_password = {
        display_name    = "Admin Password"
        type            = "STRING"
        assignment_type = "NONE"
        sensitive       = {}
      }

      summary = {
        display_name    = "Summary"
        type            = "STRING"
        assignment_type = "SUMMARY"
      }
    }
  }
}

terraform {
  required_version = ">= 1.12.0"

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.26.2"
    }
    opentelekomcloud = {
      source  = "opentelekomcloud/opentelekomcloud"
      version = ">= 1.37.0, < 2.0.0"
    }
  }
}
