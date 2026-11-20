variable "stackit_project_id" {
  type        = string
  default     = null
  description = "STACKIT project ID every instance is created in, which also suits tenants of another platform, such as Kubernetes namespaces. Null creates each instance in the STACKIT project of the tenant the building block is ordered for."
}

variable "stackit_service_account_email" {
  type        = string
  default     = null
  description = "Service account the runs act as via WIF. It must federate this definition, as the `stackit/service-account-federation` building block does, and hold `postgres-flex.admin` on the project of the instances, or on the folder of the tenant projects. Null makes `STACKIT_SERVICE_ACCOUNT_EMAIL` an input each building block names its service account in, for a composition that orders the building block."
}

variable "database_only" {
  type        = bool
  default     = false
  description = "Registers the database variant: each building block creates a database and its owner user on the instance `stackit_existing_instance_id`. False registers the instance variant, where each building block creates an instance and nothing else."

  validation {
    condition     = !var.database_only || var.stackit_project_id != null
    error_message = "The database variant needs stackit_project_id, the project of its instance."
  }
}

variable "stackit_existing_instance_id" {
  type        = string
  default     = null
  description = "ID of the PostgreSQL Flex instance in `stackit_project_id` that the database variant shares, for example the `instance_id` output of a building block of the instance variant."

  validation {
    condition     = (var.stackit_existing_instance_id != null) == var.database_only
    error_message = "Set stackit_existing_instance_id together with database_only."
  }
}

variable "stackit_acl" {
  type        = list(string)
  default     = []
  description = "Default of the Allowed Sources input of the instance variant: IPv4 CIDR ranges allowed to connect, for example the egress address of the cluster the workloads run on (`stackit ske cluster describe <name>`, `status.egressAddressRanges`). Empty gives the input no default, so every order names its sources."
}

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

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    tags                        = optional(map(list(string)), {})
    runner_ref = optional(object({
      kind = string
      uuid = string
    }))
    supported_platforms = optional(list(object({
      kind = optional(string)
      name = optional(string)
      uuid = optional(string)
    })), [{ name = "STACKIT" }])
  })
  description = "Shared meshStack context, see docs."
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
  `git_ref`: Hub release reference. Set to a tag (e.g. 'v1.2.3') or branch or commit sha of meshcloud/meshstack-hub repo.
  `bbd_draft`: If true, allows changing the building block definition for upgrading dependent building blocks.
  EOT
}

output "building_block_definition" {
  description = "BBD is consumed in building block compositions."
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = meshstack_building_block_definition.this.version_latest
  }
}

locals {
  instance_in_tenant_project = var.stackit_project_id == null
  fixed_service_account      = var.stackit_service_account_email != null

  instance_inputs = {
    instance_name = {
      display_name                   = "Instance Name"
      description                    = "Name of the PostgreSQL Flex instance."
      type                           = "STRING"
      assignment_type                = "USER_INPUT"
      value_validation_regex         = "^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$"
      validation_regex_error_message = "At most 63 lowercase letters, digits and hyphens, starting with a letter and not ending with a hyphen."
      display_order                  = 1
    }

    flavor = {
      display_name           = "Flavor"
      description            = "Size of each node as <vCPU>.<RAM in GB>."
      type                   = "SINGLE_SELECT"
      assignment_type        = "USER_INPUT"
      selectable_values      = ["2.4", "2.16", "4.8", "4.32", "8.16", "8.32", "16.32", "16.64", "16.128", "30.240"]
      default_value          = jsonencode("2.4")
      updateable_by_consumer = true
      display_order          = 2
    }

    replicas = {
      display_name           = "Replicas"
      description            = "1 for a single node, 3 for a highly available replica set."
      type                   = "SINGLE_SELECT"
      assignment_type        = "USER_INPUT"
      selectable_values      = ["1", "3"]
      default_value          = jsonencode("1")
      updateable_by_consumer = true
      display_order          = 3
    }

    storage_class = {
      display_name      = "Storage Class"
      description       = "Storage performance class, from premium-perf2-stackit (1000 IOPS) to premium-perf12-stackit (20000 IOPS). Cannot change after creation."
      type              = "SINGLE_SELECT"
      assignment_type   = "USER_INPUT"
      selectable_values = ["premium-perf2-stackit", "premium-perf4-stackit", "premium-perf6-stackit", "premium-perf8-stackit", "premium-perf10-stackit", "premium-perf12-stackit"]
      default_value     = jsonencode("premium-perf2-stackit")
      display_order     = 4
    }

    storage_size = {
      display_name           = "Storage Size (GB)"
      description            = "5 to 4000 GB. Can grow, never shrink."
      type                   = "INTEGER"
      assignment_type        = "USER_INPUT"
      default_value          = jsonencode(5)
      updateable_by_consumer = true
      display_order          = 5
    }

    postgres_version = {
      display_name      = "PostgreSQL Version"
      description       = "PostgreSQL major version. 18 is in beta at STACKIT."
      type              = "SINGLE_SELECT"
      assignment_type   = "USER_INPUT"
      selectable_values = ["15", "16", "17", "18"]
      default_value     = jsonencode("17")
      display_order     = 6
    }

    backup_schedule = {
      display_name                   = "Backup Schedule"
      description                    = "Cron expression in UTC with numeric minute and hour, for example '0 2 * * *' for 02:00 every day."
      type                           = "STRING"
      assignment_type                = "USER_INPUT"
      default_value                  = jsonencode("0 2 * * *")
      value_validation_regex         = "^([0-9]|[1-5][0-9]) ([0-9]|1[0-9]|2[0-3]) \\S+ \\S+ \\S+$"
      validation_regex_error_message = "A five-field cron expression with a numeric minute (0-59) and hour (0-23)."
      updateable_by_consumer         = true
      display_order                  = 7
    }

    backup_retention_days = {
      display_name           = "Backup Retention (days)"
      description            = "Number of days STACKIT keeps backups, 32 to 90."
      type                   = "INTEGER"
      assignment_type        = "USER_INPUT"
      default_value          = jsonencode(32)
      updateable_by_consumer = true
      display_order          = 8
    }

    acl = {
      display_name           = "Allowed Sources"
      description            = "HCL list of IPv4 CIDR ranges allowed to connect. The instance accepts no other source."
      type                   = "CODE"
      assignment_type        = "USER_INPUT"
      default_value          = length(var.stackit_acl) == 0 ? null : jsonencode(jsonencode(var.stackit_acl))
      updateable_by_consumer = true
      display_order          = 9
    }
  }

  database_inputs = {
    existing_instance_id = {
      display_name    = "Instance ID"
      description     = "ID of the shared PostgreSQL Flex instance."
      type            = "STRING"
      assignment_type = "STATIC"
      argument        = jsonencode(var.stackit_existing_instance_id)
      display_order   = 10
    }

    workspace_identifier = {
      display_name    = "Workspace"
      description     = "Database and user are named `<workspace>_<project>`, with `_` for `-`."
      type            = "STRING"
      assignment_type = "WORKSPACE_IDENTIFIER"
      display_order   = 12
    }

    project_identifier = {
      display_name    = "Project"
      description     = "Database and user are named `<workspace>_<project>`, with `_` for `-`."
      type            = "STRING"
      assignment_type = "PROJECT_IDENTIFIER"
      display_order   = 13
    }
  }

  database_outputs = {
    database = {
      display_name    = "Database"
      type            = "STRING"
      assignment_type = "NONE"
    }

    username = {
      display_name    = "Username"
      type            = "STRING"
      assignment_type = "NONE"
    }

    jdbc_url = {
      display_name    = "JDBC URL"
      type            = "STRING"
      assignment_type = "NONE"
    }

    uri = {
      display_name    = "Connection URI"
      type            = "STRING"
      assignment_type = "NONE"
    }
  }
}

# Lookup specified runner for workload identity federation info. Null results in the default hosted runner.
module "runner" {
  source = "github.com/meshcloud/meshstack-hub//modules/meshstack/runner-identity?ref=${var.hub.git_ref}"

  cloud      = "azure"
  runner_ref = var.meshstack.runner_ref
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name        = coalesce(var.bbd_display_name, var.database_only ? "STACKIT PostgreSQL Database" : "STACKIT PostgreSQL")
    symbol              = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/stackit/postgres/buildingblock/logo.png"
    description         = coalesce(var.bbd_description, var.database_only ? "Provisions a database and its owner user on a shared STACKIT PostgreSQL Flex instance." : "Provisions a managed STACKIT PostgreSQL Flex instance that databases are added to.")
    target_type         = "TENANT_LEVEL"
    run_transparency    = true
    supported_platforms = var.meshstack.supported_platforms
    readme = coalesce(var.bbd_readme, chomp(<<-EOT
      This building block provisions **managed PostgreSQL** on STACKIT PostgreSQL Flex. STACKIT
      runs the server, patches it and takes the backups. It comes in two variants:

      - **STACKIT PostgreSQL** creates an instance and nothing else. This takes about three minutes.
      - **STACKIT PostgreSQL Database** creates a database and its owner user on an instance the
        platform team shares. This takes a few seconds. Both are named `<workspace>_<project>`.

      ## 🎯 When to use it

      Use this building block when your application needs:
      - A relational database without running a PostgreSQL server yourself.
      - A database per stage: a small shared single node for development, three replicated nodes
        for production.

      ## 💡 Usage examples

      **Example 1: Database for a service on Kubernetes**
      A developer orders a database for a Spring Boot service on the namespace of each stage. A
      connector definition of the platform team puts URL, username and password into a Kubernetes
      Secret there.

      **Example 2: Production instance**
      The platform team orders the instance variant with three replicas and a larger flavor, so
      the databases on it survive the loss of a node.

      ## 🔌 Connecting

      An instance has a public endpoint that requires TLS and only accepts the sources the
      platform team allowed. The summary shows host and port, and for a database its name,
      username and JDBC URL.

      The database variant hands out no password. It is the base for connector definitions, which
      pass the credentials on. Without a connector, reset the user's password in the STACKIT portal.

      On a shared instance your user owns your database and cannot create others. Users of other
      databases can never read or change your data. A connector also stops them from connecting to
      your database at all; without one they can connect and see table names.

      ## 🧩 A shared instance per stage

      1. The platform team orders **STACKIT PostgreSQL** once per stage and notes each **Instance ID**.
      2. It publishes one database definition per landing zone, each with the instance of that
         stage (`database_only = true`, `stackit_existing_instance_id`) and the platform's service
         account (`stackit_service_account_email`), so the order form asks for nothing.
      3. To hand the credentials to workloads, it publishes a connector instead: a building block
         of its own that wraps the database module and writes a Kubernetes Secret into the
         tenant's namespace:

      ```hcl
      module "database" {
        source = "github.com/meshcloud/meshstack-hub//modules/stackit/postgres/buildingblock/modules/database?ref=main"

        project_id    = var.stackit_project_id   # STATIC
        instance_id   = var.existing_instance_id # STATIC, per landing zone
        database_name = local.name               # from workspace and project identifier
        username      = local.name
      }

      resource "kubernetes_secret_v1" "datasource" {
        metadata {
          name      = "postgres"
          namespace = var.namespace # PLATFORM_TENANT_ID
        }

        data = {
          SPRING_DATASOURCE_URL      = module.database.jdbc_url
          SPRING_DATASOURCE_USERNAME = module.database.username
          SPRING_DATASOURCE_PASSWORD = module.database.password
        }
      }
      ```

      The password goes from the module straight into the Secret and is no building block output.
      A pod reads all three keys with `envFrom`. The connector also runs a Job in the namespace
      that executes `REVOKE ALL ON DATABASE <database> FROM PUBLIC` as the owner, which closes the
      database to the other users of the instance. The module's README has the complete example.

      ## 📊 Shared Responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Provision instances, databases and their owners | ✅ | ❌ |
      | Decide which networks may connect | ✅ | ❌ |
      | Operate the server, patch it and take backups (STACKIT) | ✅ | ❌ |
      | Size and availability of a shared instance | ✅ | ❌ |
      | Hand the credentials to workloads through a connector | ✅ | ❌ |
      | Schema, migrations and query performance | ❌ | ✅ |
      | Keep the credentials secret and restore from backups when needed | ❌ | ✅ |
      EOT
    ))
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"
    runner_ref    = module.runner.ref

    implementation = {
      terraform = {
        terraform_version              = "1.12.5"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/stackit/postgres/buildingblock"
        ref_name                       = var.hub.git_ref
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = merge(
      { for key, input in local.instance_inputs : key => input if !var.database_only },
      { for key, input in local.database_inputs : key => input if var.database_only },
      {
        project_id = {
          display_name    = "STACKIT Project ID"
          description     = "STACKIT project ID the instance is created in."
          type            = "STRING"
          assignment_type = local.instance_in_tenant_project ? "PLATFORM_TENANT_ID" : "STATIC"
          argument        = local.instance_in_tenant_project ? null : jsonencode(var.stackit_project_id)
          display_order   = 11
        }

        STACKIT_SERVICE_ACCOUNT_EMAIL = {
          display_name           = "STACKIT Service Account Email"
          description            = "Email of the STACKIT service account the provider authenticates as via WIF. It federates this definition and holds `postgres-flex.admin`."
          type                   = "STRING"
          assignment_type        = local.fixed_service_account ? "STATIC" : "USER_INPUT"
          is_environment         = true
          argument               = local.fixed_service_account ? jsonencode(var.stackit_service_account_email) : null
          updateable_by_consumer = !local.fixed_service_account
        }

        STACKIT_USE_OIDC = {
          display_name    = "STACKIT Use OIDC"
          description     = "Enables OIDC-based WIF for the STACKIT provider."
          type            = "STRING"
          assignment_type = "STATIC"
          is_environment  = true
          argument        = jsonencode("1")
        }

        STACKIT_FEDERATED_TOKEN_FILE = {
          display_name    = "STACKIT Federated Token File"
          description     = "Path to the WIF token file injected by meshStack."
          type            = "STRING"
          assignment_type = "STATIC"
          is_environment  = true
          argument        = jsonencode(module.runner.token_path)
        }
      }
    )

    outputs = merge(
      {
        instance_id = {
          display_name    = "Instance ID"
          type            = "STRING"
          assignment_type = "NONE"
        }

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

        summary = {
          display_name    = "Summary"
          type            = "STRING"
          assignment_type = "SUMMARY"
        }
      },
      { for key, output in local.database_outputs : key => output if var.database_only }
    )
  }
}

terraform {
  required_version = ">= 1.12.0"

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.27.2"
    }
  }
}
