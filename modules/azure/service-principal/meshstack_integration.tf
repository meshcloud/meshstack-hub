variable "azure_tenant_id" {
  type        = string
  description = "Azure Entra tenant ID where service principals will be created."
}

variable "azure_scope" {
  type        = string
  description = "Azure management group or subscription ID used for backplane role scope."
}

variable "backplane_name" {
  type        = string
  default     = "azure-service-principal"
  description = "Name for the backplane resources (service principal, role definition). Must match pattern ^[-a-z0-9]+$."
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
  default     = {}
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
  source = "github.com/meshcloud/meshstack-hub//modules/azure/service-principal/backplane?ref=3d8dbbdc0bda60ae4192212814d01985cccaf5a8"

  name  = var.backplane_name
  scope = var.azure_scope

  create_service_principal_name = var.backplane_name

  workload_identity_federation = {
    issuer  = data.meshstack_integrations.integrations.workload_identity_federation.replicator.issuer
    subject = "${trimsuffix(data.meshstack_integrations.integrations.workload_identity_federation.replicator.subject, ":replicator")}:workspace.${var.meshstack.owning_workspace_identifier}.buildingblockdefinition.${meshstack_building_block_definition.this.metadata.uuid}"
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name             = "Azure Service Principal"
    description              = "Creates an Azure AD application and service principal with configurable role assignments on the target subscription."
    support_url              = "mailto:support@meshcloud.io"
    documentation_url        = "https://hub.meshcloud.io/platforms/azure/definitions/azure-service-principal"
    notification_subscribers = var.notification_subscribers
    symbol                   = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/main/modules/azure/service-principal/buildingblock/logo.png"
    target_type              = "WORKSPACE_LEVEL"

    readme = chomp(<<-EOT
      ## Azure Service Principal

      This building block creates an **Azure AD Application** and **Service Principal** with role assignments on your Azure subscription.

      ## When to use it?

      Use this building block when your applications need:
      - A service identity for Azure authentication
      - Programmatic access to Azure resources
      - CI/CD pipeline authentication with Azure
      - Workload identity for containerized applications

      ## Features

      - Creates Azure AD Application and Service Principal
      - Supports built-in roles (Contributor, Reader, Owner, etc.)
      - Supports custom role definitions with granular permissions
      - Automatic secret rotation with configurable expiration
      - Optional workload identity federation support

      ## Shared Responsibilities

      | Responsibility                              | Platform Team | Application Team |
      | ------------------------------------------- | :-----------: | :--------------: |
      | Provision service principal                 | ✅            | ❌               |
      | Define available roles                      | ✅            | ❌               |
      | Choose role assignment                      | ❌            | ✅               |
      | Manage client secrets securely              | ❌            | ✅               |
      | Configure workload identity federation      | ❌            | ✅               |
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
        repository_path                = "modules/azure/service-principal/buildingblock"
        ref_name                       = var.hub.git_ref
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      ARM_CLIENT_ID = {
        type            = "STRING"
        display_name    = "ARM Client ID"
        description     = "Client ID of the service principal used to authenticate with Azure."
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(module.backplane.created_service_principal.client_id)
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
        argument        = jsonencode("/var/run/secrets/workload-identity/azure/token")
      }
      display_name = {
        type            = "STRING"
        display_name    = "Display Name"
        description     = "Display name for the Azure AD application and service principal."
        assignment_type = "USER_INPUT"
      }
      description = {
        type            = "STRING"
        display_name    = "Description"
        description     = "Description for the Azure AD application."
        assignment_type = "USER_INPUT"
        argument        = jsonencode("Service principal managed by meshStack")
      }
      azure_subscription_id = {
        type            = "STRING"
        display_name    = "Azure Subscription ID"
        description     = "The Azure subscription ID where role assignments will be created."
        assignment_type = "PLATFORM_TENANT_ID"
      }
      azure_role = {
        type            = "STRING"
        display_name    = "Azure Role"
        description     = "Azure RBAC built-in role to assign (e.g., 'Contributor', 'Reader'). Leave empty if using a custom role."
        assignment_type = "USER_INPUT"
        argument        = jsonencode("Contributor")
      }
      create_client_secret = {
        type            = "BOOLEAN"
        display_name    = "Create Client Secret"
        description     = "Whether to create a client secret for the service principal."
        assignment_type = "USER_INPUT"
        argument        = jsonencode(true)
      }
      secret_rotation_days = {
        type            = "INTEGER"
        display_name    = "Secret Rotation Days"
        description     = "Number of days before the client secret expires (30-730 days)."
        assignment_type = "USER_INPUT"
        argument        = jsonencode(90)
      }
    }

    outputs = {
      application_id = {
        type            = "STRING"
        display_name    = "Application (Client) ID"
        description     = "The application (client) ID of the created Azure AD application."
        assignment_type = "NONE"
      }
      service_principal_object_id = {
        type            = "STRING"
        display_name    = "Service Principal Object ID"
        description     = "The object ID of the created service principal."
        assignment_type = "NONE"
      }
      client_secret = {
        type            = "STRING"
        display_name    = "Client Secret"
        description     = "The client secret for the service principal (if created)."
        assignment_type = "NONE"
        is_sensitive    = true
      }
      tenant_id = {
        type            = "STRING"
        display_name    = "Tenant ID"
        description     = "The Azure Entra tenant ID."
        assignment_type = "NONE"
      }
      subscription_id = {
        type            = "STRING"
        display_name    = "Subscription ID"
        description     = "The Azure subscription ID where the role assignment was created."
        assignment_type = "NONE"
      }
      role_name = {
        type            = "STRING"
        display_name    = "Role Name"
        description     = "The name of the role assigned to the service principal."
        assignment_type = "NONE"
      }
      secret_expiration_date = {
        type            = "STRING"
        display_name    = "Secret Expiration Date"
        description     = "The date when the client secret will expire."
        assignment_type = "NONE"
      }
    }
  }
}

terraform {
  required_version = ">= 1.11.0"

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = "~> 0.20.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.64"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.8"
    }
  }
}
