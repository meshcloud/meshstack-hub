variable "azure_tenant_id" {
  type        = string
  description = "Azure Entra tenant ID the landing zone subscriptions belong to."
}

variable "azure_scope" {
  type        = string
  description = "RBAC scope where the deploy role is granted: a management group ('/providers/Microsoft.Management/managementGroups/<id>') or a subscription ('/subscriptions/<guid>'), typically the parent of all landing zones."
  validation {
    condition     = can(regex("^/subscriptions/[0-9a-fA-F-]{36}$|^/providers/Microsoft\\.Management/managementGroups/.+$", var.azure_scope))
    error_message = "Must be a full resource path: '/subscriptions/<guid>' or '/providers/Microsoft.Management/managementGroups/<id>', not a bare GUID."
  }
}

variable "azure_location" {
  type        = string
  default     = "westeurope"
  description = "Azure region of the backplane identity and of every PostgreSQL Flexible Server. Check that the region offers Flexible Server to your subscriptions with `az postgres flexible-server list-skus -l <region>`: some regions, such as germanywestcentral, restrict it."
}

variable "backplane_name" {
  type        = string
  default     = "azure-postgresql"
  description = "Name for the backplane resources (identity, resource group, role definition). Must match pattern ^[-a-z0-9]+$."
}

variable "notification_subscribers" {
  type        = list(string)
  default     = []
  description = "List of email addresses to notify on building block lifecycle events."
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
    additional_trusted_runner_refs = optional(list(object({
      kind = string
      uuid = string
    })), [])
    supported_platforms = optional(list(object({
      kind = optional(string)
      name = optional(string)
      uuid = optional(string)
    })), [{ name = "AZURE" }])
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
  `git_ref`: Hub release reference. Set to a tag (e.g. 'v1.2.3') or branch or commit sha of the meshstack-hub repo.
  `bbd_draft`: If true, the building block definition version is kept in draft mode.
  EOT
}

# Lookup specified runner for workload identity federation info. Null results in the default hosted runner.
module "runner" {
  source = "github.com/meshcloud/meshstack-hub//modules/meshstack/runner-identity?ref=${var.hub.git_ref}"

  cloud                          = "azure"
  runner_ref                     = var.meshstack.runner_ref
  additional_trusted_runner_refs = var.meshstack.additional_trusted_runner_refs
  versions                       = meshstack_building_block_definition.this.versions
}

output "building_block_definition" {
  description = "BBD is consumed in building block compositions."
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  }
}

module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/azure/postgresql/backplane?ref=${var.hub.git_ref}"

  name     = var.backplane_name
  scope    = var.azure_scope
  location = var.azure_location

  workload_identity_federation = {
    issuer   = module.runner.issuer
    audience = module.runner.audience
    subjects = [meshstack_building_block_definition.this.version_latest.workload_identity_federation.subject]
  }

  trusted_runner_identities = module.runner.trusted_identities
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name             = coalesce(var.bbd_display_name, "Azure PostgreSQL")
    description              = coalesce(var.bbd_description, "Provides an Azure Database for PostgreSQL Flexible Server in your subscription.")
    support_url              = "mailto:support@meshcloud.io"
    documentation_url        = "https://hub.meshcloud.io/platforms/azure/definitions/azure-postgresql"
    notification_subscribers = var.notification_subscribers
    symbol                   = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/azure/postgresql/buildingblock/logo.png"
    target_type              = "TENANT_LEVEL"
    supported_platforms      = var.meshstack.supported_platforms
    run_transparency         = true

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
      This building block creates an **Azure Database for PostgreSQL Flexible Server** in a new resource group in your Azure subscription. Azure runs the server for you: it installs updates, takes backups and keeps the server available.

      ## 🎯 When to use it

      Use this building block when you:
      - Need a PostgreSQL database for your application and do not want to run the database server yourself.
      - Want to start small and cheap, and move to a bigger SKU later.

      ## 💡 Usage examples

      **Example 1: Database for a web application**
      A team orders a Burstable server for its web application, creates the application's database and user, and stores the connection string in its Key Vault.

      **Example 2: Reporting database**
      A data team orders a General Purpose server with more storage and connects its reporting tool to it.

      ## 🔐 Access

      The building block creates the administrator user `psqladmin` with a random password and does not hand it out. Set a new password with **Reset password** on the server's overview page in the Azure Portal.

      Public network access is off by default. If you turn it on, no client can connect until you add firewall rules for its IP addresses. Connections always use TLS 1.2 or newer.

      ## 📊 Shared Responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Provide the server with secure defaults | ✅ | ❌ |
      | Run updates and backups of the server | ✅ | ❌ |
      | Set the administrator password and manage database users | ❌ | ✅ |
      | Add firewall rules or private network access | ❌ | ✅ |
      | Create databases, schemas and tables | ❌ | ✅ |
      | Tune queries and choose the right SKU | ❌ | ✅ |
    EOT
    ))
  }

  version_spec = {
    draft = var.hub.bbd_draft

    deletion_mode = "DELETE"
    runner_ref    = module.runner.ref

    implementation = {
      terraform = {
        terraform_version              = "1.12.5"
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
        description     = "Client ID of the UAMI used to authenticate with Azure."
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
        argument        = jsonencode(module.runner.token_path)
      }
      postgresql_server_name = {
        type                           = "STRING"
        display_name                   = "Server Name"
        description                    = "Name of the PostgreSQL server. It is part of the server's DNS name, so it must be unique across Azure."
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$"
        validation_regex_error_message = "3 to 63 characters: lowercase letters, digits and dashes, starting and ending with a letter or digit."
        display_order                  = 1
      }
      resource_group_name = {
        type                           = "STRING"
        display_name                   = "Resource Group Name"
        description                    = "Resource group the building block creates for the server. It is deleted with the building block."
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[-\\w\\._\\(\\)]{1,90}$"
        validation_regex_error_message = "1 to 90 characters: letters, digits, underscores, dashes, periods and parentheses."
        display_order                  = 2
      }
      postgresql_version = {
        type              = "SINGLE_SELECT"
        display_name      = "PostgreSQL Version"
        description       = "PostgreSQL major version. You can upgrade later, but not downgrade."
        assignment_type   = "USER_INPUT"
        selectable_values = ["14", "15", "16", "17"]
        default_value     = jsonencode("17")
        display_order     = 3
      }
      sku_name = {
        type              = "SINGLE_SELECT"
        display_name      = "SKU"
        description       = "Size of the server. Burstable (B_) is cheapest, General Purpose (GP_) is for steady load."
        assignment_type   = "USER_INPUT"
        selectable_values = ["B_Standard_B1ms", "B_Standard_B2s", "GP_Standard_D2ds_v5", "GP_Standard_D4ds_v5"]
        default_value     = jsonencode("B_Standard_B1ms")
        display_order     = 4
      }
      storage_mb = {
        type              = "SINGLE_SELECT"
        display_name      = "Storage (MB)"
        description       = "Storage size in MB. Storage can grow later, but not shrink."
        assignment_type   = "USER_INPUT"
        selectable_values = ["32768", "65536", "131072", "262144"]
        default_value     = jsonencode("32768")
        display_order     = 5
      }
      public_network_access_enabled = {
        type            = "BOOLEAN"
        display_name    = "Public Network Access"
        description     = "Allow connections from the internet. No client can connect until you add firewall rules for it."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(false)
        display_order   = 6
      }
      subscription_id = {
        type            = "STRING"
        display_name    = "Subscription ID"
        description     = "The Azure subscription the server is created in."
        assignment_type = "PLATFORM_TENANT_ID"
      }
      location = {
        type            = "STRING"
        display_name    = "Location"
        description     = "The Azure region the server is created in."
        assignment_type = "STATIC"
        argument        = jsonencode(var.azure_location)
      }
    }

    outputs = {
      postgresql_server_name = {
        type            = "STRING"
        display_name    = "Server Name"
        description     = "The name of the PostgreSQL Flexible Server."
        assignment_type = "NONE"
      }
      postgresql_fqdn = {
        type            = "STRING"
        display_name    = "Host"
        description     = "The host name clients connect to."
        assignment_type = "NONE"
      }
      postgresql_admin_username = {
        type            = "STRING"
        display_name    = "Administrator"
        description     = "The administrator user of the server."
        assignment_type = "NONE"
      }
      postgresql_version = {
        type            = "STRING"
        display_name    = "PostgreSQL Version"
        description     = "The PostgreSQL major version."
        assignment_type = "NONE"
      }
      resource_group_name = {
        type            = "STRING"
        display_name    = "Resource Group"
        description     = "The resource group that holds the server."
        assignment_type = "NONE"
      }
      postgresql_portal_url = {
        type            = "STRING"
        display_name    = "Open PostgreSQL Server"
        description     = "Azure Portal URL of the server."
        assignment_type = "RESOURCE_URL"
      }
      summary = {
        type            = "STRING"
        display_name    = "Summary"
        description     = "A markdown summary of the server and how to get access."
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
      version = ">= 0.27.2"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.65.0, < 5.0.0"
    }
  }
}
