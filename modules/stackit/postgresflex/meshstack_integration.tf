variable "stackit_organization_id" {
  type        = string
  description = "STACKIT organization ID under which target projects live."
}

variable "stackit_project_id" {
  type        = string
  description = "STACKIT project ID where the backplane service account will be created."
}

variable "stackit_service_account_name" {
  type        = string
  default     = null
  description = "Name of the backplane service account. Defaults to 'mesh-postgresflex'. Override when deploying multiple backplane instances in the same STACKIT project."
}

variable "stackit_region" {
  type        = string
  default     = "eu01"
  description = "STACKIT region the PostgreSQL Flex instances are created in."
}

variable "stackit_postgresflex_acl" {
  type    = list(string)
  default = ["193.148.160.0/19", "45.129.40.0/21", "45.135.244.0/22"]

  description = <<-EOT
  Source IPv4 CIDR ranges offered as the default ACL of an ordered instance. The default is the set
  of STACKIT service ranges that STACKIT documents as the predefined ACL for its data services. An
  SKE cluster reaches the instance through a NAT router, so the application team adds the cluster's
  public egress IP as a /32 entry when it is not already covered.
  EOT
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    tags                        = optional(map(list(string)), {})
  })
  description = "Shared meshStack context."
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
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  }
}

data "meshstack_integrations" "integrations" {}

module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/postgresflex/backplane?ref=${var.hub.git_ref}"

  project_id           = var.stackit_project_id
  organization_id      = var.stackit_organization_id
  service_account_name = coalesce(var.stackit_service_account_name, "mesh-postgresflex")

  workload_identity_federation = {
    issuer = data.meshstack_integrations.integrations.workload_identity_federation.replicator.issuer
    subjects = [
      "${trimsuffix(data.meshstack_integrations.integrations.workload_identity_federation.replicator.subject, ":replicator")}:workspace.${var.meshstack.owning_workspace_identifier}.buildingblockdefinition.${meshstack_building_block_definition.this.metadata.uuid}"
    ]
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name        = "STACKIT PostgreSQL Flex"
    symbol              = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/stackit/postgresflex/buildingblock/logo.png"
    description         = "Provisions a managed STACKIT PostgreSQL Flex instance with a database and a database user."
    support_url         = "https://portal.stackit.cloud"
    target_type         = "TENANT_LEVEL"
    run_transparency    = true
    supported_platforms = [{ name = "STACKIT" }]
    readme = chomp(<<-EOT
      This building block provisions a **managed PostgreSQL Flex instance on STACKIT** inside your
      STACKIT project, together with one database and one database user, so your application gets a
      relational database without anyone running a Postgres server.

      ## 🎯 When to use it

      Use this building block when you:
      - Need a managed PostgreSQL database for an application running in your STACKIT project.
      - Want STACKIT to take the daily backups and to keep the engine patched.
      - Prefer a single connection string over assembling host, port, user and password yourself.

      ## 💡 Usage examples

      **Example 1: Database for a workload on SKE**
      A team runs an API on an SKE cluster and orders this building block for its persistent data.
      The team puts the cluster's public egress IP into the ACL and feeds the connection string into
      the deployment as an environment variable.

      **Example 2: Database for an AI gateway**
      An AI platform runs LiteLLM and Langfuse, and both need their own PostgreSQL. The team orders
      this building block twice, once per component, and hands each the connection string as its
      `DATABASE_URL`.

      ## 🔒 Reaching the instance

      A PostgreSQL Flex instance only accepts connections from the source ranges listed in its ACL.
      The default covers the STACKIT service ranges. An SKE cluster leaves its network through a
      router that applies NAT, so the instance sees the cluster's public egress IP rather than a
      private address — add that address as a `/32` entry when your cluster is not already covered.
      You find the egress IP in the STACKIT Portal under the cluster's overview. Do not add
      `0.0.0.0/0`, it would open the instance to every address on the internet.

      ## 🗓️ Version support

      PostgreSQL 14 reaches end of life on **12 November 2026**, and 13 is already past it. Order
      version 16 or newer.

      ## 📊 Shared Responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Provide the backplane identity used to create the instance | ✅ | ❌ |
      | Run the managed PostgreSQL service, its patches and its backups | ✅ | ❌ |
      | Offer a sensible default ACL of STACKIT service ranges | ✅ | ❌ |
      | Choose instance size, storage, PostgreSQL version and backup schedule | ❌ | ✅ |
      | Add the client source ranges the application connects from | ❌ | ✅ |
      | Database schema, migrations and query performance | ❌ | ✅ |
      | Keep the returned credentials secret and rotate them when needed | ❌ | ✅ |
      EOT
    )
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"

    implementation = {
      terraform = {
        terraform_version              = "1.11.0"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/stackit/postgresflex/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      project_id = {
        display_name    = "STACKIT Project ID"
        description     = "STACKIT project ID of the existing project the instance will be created in."
        type            = "STRING"
        assignment_type = "PLATFORM_TENANT_ID"
      }

      service_account_email = {
        display_name    = "Service Account Email"
        description     = "Email of the STACKIT service account for WIF-based authentication."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(module.backplane.service_account_email)
      }

      stackit_region = {
        display_name    = "STACKIT Region"
        description     = "STACKIT region the instance is created in."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.stackit_region)
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
        argument        = jsonencode("/var/run/secrets/workload-identity/azure/token")
      }

      instance_name = {
        display_name                   = "Instance Name"
        description                    = "Name of the PostgreSQL Flex instance."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[a-z0-9]([a-z0-9-]*[a-z0-9])?$"
        validation_regex_error_message = "The instance name may contain lowercase letters, digits and hyphens, and must start and end with a letter or a digit."
      }

      flavor_cpu = {
        display_name    = "vCPUs"
        description     = "Number of vCPUs. Valid CPU/RAM pairs are 2/4, 4/8, 16/32, 2/16, 4/32, 16/128 and 8/16."
        type            = "INTEGER"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(2)
      }

      flavor_ram = {
        display_name    = "Memory (GiB)"
        description     = "Memory in GiB. Must form a valid pair with the number of vCPUs."
        type            = "INTEGER"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(4)
      }

      replicas = {
        display_name                   = "Replicas"
        description                    = "Number of nodes. 1 creates a single-node instance, 3 creates a replicated instance."
        type                           = "INTEGER"
        assignment_type                = "USER_INPUT"
        default_value                  = jsonencode(1)
        value_validation_regex         = "^(1|3)$"
        validation_regex_error_message = "Replicas must be either 1 or 3."
      }

      storage_class = {
        display_name                   = "Storage Class"
        description                    = "Storage performance class, from premium-perf2-stackit up to premium-perf12-stackit."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        default_value                  = jsonencode("premium-perf2-stackit")
        value_validation_regex         = "^premium-perf(2|4|6|8|10|12)-stackit$"
        validation_regex_error_message = "Storage class must be one of premium-perf2-stackit, premium-perf4-stackit, premium-perf6-stackit, premium-perf8-stackit, premium-perf10-stackit, premium-perf12-stackit."
      }

      storage_size = {
        display_name    = "Storage Size (GB)"
        description     = "Storage size of the instance in GB."
        type            = "INTEGER"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(20)
      }

      postgres_version = {
        display_name                   = "PostgreSQL Version"
        description                    = "PostgreSQL major version. Version 14 reaches end of life on 12 November 2026, so pick 16 or newer."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        default_value                  = jsonencode("17")
        value_validation_regex         = "^(1[6-9]|[2-9][0-9])$"
        validation_regex_error_message = "The PostgreSQL version must be 16 or newer."
      }

      backup_schedule = {
        display_name    = "Backup Schedule"
        description     = "Cron expression that decides when STACKIT takes the daily backup. Minute and hour must be numeric, for example '0 2 * * *' for 02:00 UTC."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("0 2 * * *")
      }

      retention_days = {
        display_name    = "Backup Retention (days)"
        description     = "Number of days STACKIT keeps backups. STACKIT accepts 32 to 90."
        type            = "INTEGER"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(32)
      }

      acl = {
        display_name    = "Allowed Source Ranges"
        description     = "JSON list of IPv4 CIDR ranges allowed to connect. Keep the STACKIT service ranges and add your SKE cluster's public egress IP as a /32 entry. Do not add 0.0.0.0/0."
        type            = "CODE"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(jsonencode(var.stackit_postgresflex_acl))
      }

      database_name = {
        display_name                   = "Database Name"
        description                    = "Name of the database created on the instance."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        default_value                  = jsonencode("app")
        value_validation_regex         = "^[a-z_][a-z0-9_]*$"
        validation_regex_error_message = "The database name may contain lowercase letters, digits and underscores, and must not start with a digit."
      }

      database_username = {
        display_name                   = "Database Username"
        description                    = "Name of the database user that owns the database."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        default_value                  = jsonencode("app")
        value_validation_regex         = "^[a-z_][a-z0-9_]*$"
        validation_regex_error_message = "The username may contain lowercase letters, digits and underscores, and must not start with a digit."
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

      database_name = {
        display_name    = "Database Name"
        type            = "STRING"
        assignment_type = "NONE"
      }

      username = {
        display_name    = "Username"
        type            = "STRING"
        assignment_type = "NONE"
      }

      password = {
        display_name    = "Password"
        type            = "STRING"
        assignment_type = "NONE"
      }

      connection_string = {
        display_name    = "Connection String"
        type            = "STRING"
        assignment_type = "NONE"
      }

      instance_id = {
        display_name    = "Instance ID"
        type            = "STRING"
        assignment_type = "NONE"
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
      version = ">= 0.21.0"
    }
    stackit = {
      source  = "stackitcloud/stackit"
      version = ">= 0.110.0"
    }
  }
}
