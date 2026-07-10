variable "azure_tenant_id" {
  type        = string
  description = "Azure Entra tenant ID where the PostgreSQL Flexible Server will be deployed."
}

variable "azure_subscription_id" {
  type        = string
  description = "Azure subscription ID where the PostgreSQL Flexible Server will be deployed."
}

variable "azure_scope" {
  type        = string
  description = "Azure management group or subscription ID used for backplane role scope."
}

variable "azure_location" {
  type        = string
  default     = "germanywestcentral"
  description = "Default Azure region where the PostgreSQL Flexible Server will be created."
}

variable "backplane_name" {
  type        = string
  default     = "azure-postgresql"
  description = "Name for the backplane resources (managed identity, role definition). Must match pattern ^[-a-z0-9]+$."
}

variable "notification_subscribers" {
  type        = list(string)
  default     = []
  description = "List of email addresses to notify on building block lifecycle events."
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
  `bbd_draft`: If true, the building block definition version is kept in draft mode, which allows changing it (useful during development in LCF/ICF).
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
  source = "github.com/meshcloud/meshstack-hub//modules/azure/postgresql/backplane?ref=${var.hub.git_ref}"

  name     = var.backplane_name
  scope    = var.azure_scope
  location = var.azure_location

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
    display_name             = "Azure PostgreSQL"
    description              = "Provisions a managed Azure Database for PostgreSQL Flexible Server in the target Azure subscription."
    support_url              = "mailto:support@meshcloud.io"
    documentation_url        = "https://hub.meshcloud.io/platforms/azure/definitions/azure-postgresql"
    notification_subscribers = var.notification_subscribers
    symbol                   = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/main/modules/azure/postgresql/buildingblock/logo.png"
    target_type              = "WORKSPACE_LEVEL"

    readme = chomp(<<-EOT
      This building block provisions a managed **Azure Database for PostgreSQL Flexible Server** in your Azure subscription, providing a fully managed, scalable, and secure relational database service.

      ## 🎯 When to use it

      Use this building block when your application needs a reliable, managed PostgreSQL database without the operational overhead of self-hosting — for structured data storage, transactional workloads, or as a backend for reporting and analytics.

      ## 📝 What you get

      A dedicated resource group and a PostgreSQL Flexible Server with a generated administrator password (exposed as a sensitive output), sensible defaults for SKU, version, storage, and backups, and a globally-unique server name.

      ## Shared Responsibilities

      | Responsibility                                        | Platform Team | Application Team |
      | ----------------------------------------------------- | :-----------: | :--------------: |
      | Provision and configure the PostgreSQL server         | ✅            | ❌               |
      | Enforce security policies (encryption, TLS, backups)  | ✅            | ❌               |
      | Manage database backups and disaster recovery         | ✅            | ❌               |
      | Choose the server name and region                     | ❌            | ✅               |
      | Create and manage database schemas and tables         | ❌            | ✅               |
      | Application-level performance tuning and query design | ❌            | ✅               |
    EOT
    )
  }

  version_spec = {
    draft = var.hub.bbd_draft

    deletion_mode = "DELETE"

    implementation = {
      terraform = {
        terraform_version              = "1.9.0"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/azure/postgresql/buildingblock"
        ref_name                       = var.hub.git_ref
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      ARM_CLIENT_ID = {
        type            = "STRING"
        display_name    = "ARM Client ID"
        description     = "Client ID of the managed identity used to authenticate with Azure."
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(module.backplane.identity.client_id)
      }
      ARM_TENANT_ID = {
        type            = "STRING"
        display_name    = "ARM Tenant ID"
        description     = "Azure Entra tenant ID for authentication."
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(var.azure_tenant_id)
      }
      ARM_SUBSCRIPTION_ID = {
        type            = "STRING"
        display_name    = "Azure Subscription ID"
        description     = "The Azure subscription ID where the PostgreSQL server will be deployed."
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(var.azure_subscription_id)
      }
      ARM_USE_OIDC = {
        type            = "STRING"
        display_name    = "ARM Use OIDC"
        description     = "Enables OIDC-based workload identity federation for the Azure provider."
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode("true")
      }
      ARM_OIDC_TOKEN_FILE_PATH = {
        type            = "STRING"
        display_name    = "ARM OIDC Token File Path"
        description     = "Path to the OIDC token file used for workload identity federation authentication."
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode("/var/run/secrets/workload-identity/azure/token")
      }
      postgresql_server_name = {
        type                           = "STRING"
        display_name                   = "PostgreSQL Server Name"
        description                    = "A name prefix for the PostgreSQL Flexible Server. A random 5-character suffix will be appended to ensure global uniqueness. Only lowercase letters, numbers and hyphens, 3–57 characters."
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[a-z0-9-]{3,57}$"
        validation_regex_error_message = "Only lowercase letters, numbers and hyphens are allowed, between 3 and 57 characters (a 6-character suffix will be appended, keeping the final name within Azure's 63-character limit)."
      }
      location = {
        type            = "STRING"
        display_name    = "Location"
        description     = "The Azure region where the PostgreSQL server will be created."
        assignment_type = "STATIC"
        argument        = jsonencode(var.azure_location)
      }
    }

    outputs = {
      postgresql_server_id = {
        type            = "STRING"
        display_name    = "PostgreSQL Server ID"
        description     = "The Azure resource ID of the created PostgreSQL Flexible Server."
        assignment_type = "NONE"
      }
      postgresql_server_name = {
        type            = "STRING"
        display_name    = "PostgreSQL Server Name"
        description     = "The name of the created PostgreSQL Flexible Server."
        assignment_type = "NONE"
      }
      postgresql_fqdn = {
        type            = "STRING"
        display_name    = "PostgreSQL FQDN"
        description     = "The fully qualified domain name of the PostgreSQL Flexible Server."
        assignment_type = "NONE"
      }
      resource_group_name = {
        type            = "STRING"
        display_name    = "Resource Group"
        description     = "The name of the resource group containing the PostgreSQL server."
        assignment_type = "NONE"
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
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.64"
    }
  }
}
