variable "azure_tenant_id" {
  type        = string
  description = "Azure Entra tenant ID used for provider authentication."
}

variable "azure_subscription_id" {
  type        = string
  description = "Azure subscription that hosts the AKS cluster."
}

variable "azure_scope" {
  type        = string
  description = "Azure management group or subscription scope the custom role definition is assignable at. Must contain the AKS cluster."
}

variable "azure_location" {
  type        = string
  description = "Azure region for the backplane's managed identity."
}

variable "aks_cluster_name" {
  type        = string
  description = "Name of the existing AKS cluster namespaces are created in."
}

variable "aks_resource_group_name" {
  type        = string
  description = "Resource group of the AKS cluster."
}

variable "acr_id" {
  type        = string
  default     = null
  description = "Resource ID of the Azure Container Registry workloads pull from. When set, the cluster's kubelet identity gets AcrPull on it."
}

variable "azure_user_lookup_attribute" {
  type        = string
  default     = "email"
  description = "Directory attribute used to match meshStack workspace members to Entra users. 'email' matches the user's SMTP address and is the right choice when members are B2B guests, whose user principal name is rewritten on invitation. 'upn' only works for members native to this tenant."

  validation {
    condition     = contains(["upn", "email"], var.azure_user_lookup_attribute)
    error_message = "Must be 'upn' or 'email'."
  }
}

variable "azure_group_name_prefix" {
  type        = string
  default     = ""
  description = "Prepended to the display names of the Entra groups created per namespace. Leave empty to omit."
}

variable "workspace_role_mapping" {
  type = map(string)
  default = {
    "Workspace Owner"   = "admin"
    "Workspace Manager" = "admin"
    "Workspace Member"  = "edit"
  }
  description = "Maps a meshStack workspace role name to the namespace role (admin, edit or view) its members get in every namespace. A workspace role missing here gets no access."
}

variable "resource_quota" {
  type = object({
    requests_cpu    = optional(string, "2")
    requests_memory = optional(string, "4Gi")
    limits_cpu      = optional(string, "4")
    limits_memory   = optional(string, "8Gi")
    pods            = optional(string, "50")
  })
  default = {
    requests_cpu    = "2"
    requests_memory = "4Gi"
    limits_cpu      = "4"
    limits_memory   = "8Gi"
    pods            = "50"
  }
  description = "ResourceQuota applied to every namespace the building block creates. Application teams cannot change it."
}

variable "backplane_name" {
  type        = string
  default     = "azure-aks-namespace"
  description = "Name for the backplane resources (UAMI, role definition). Must match pattern ^[-a-z0-9]+$."
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

output "building_block_definition" {
  description = "BBD is consumed in building block compositions."
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  }
}

module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/azure/aks-namespace/backplane?ref=${var.hub.git_ref}"

  name     = var.backplane_name
  scope    = var.azure_scope
  location = var.azure_location

  aks = {
    cluster_name        = var.aks_cluster_name
    resource_group_name = var.aks_resource_group_name
  }
  acr_id = var.acr_id

  workload_identity_federation = {
    issuer   = meshstack_building_block_definition.this.version_latest.workload_identity_federation.issuer
    subjects = [meshstack_building_block_definition.this.version_latest.workload_identity_federation.subject]
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name             = coalesce(var.bbd_display_name, "Azure AKS Namespace")
    description              = coalesce(var.bbd_description, "A Kubernetes namespace on the shared AKS cluster, with a resource quota and access for your workspace members.")
    support_url              = "mailto:support@meshcloud.io"
    documentation_url        = "https://hub.meshcloud.io/platforms/azure/definitions/azure-aks-namespace"
    notification_subscribers = var.notification_subscribers
    symbol                   = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/azure/aks-namespace/buildingblock/logo.png"
    target_type              = "WORKSPACE_LEVEL"

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
      Creates a **Kubernetes namespace** on the platform team's AKS cluster for your workspace. You
      get an isolated place to run workloads, with a resource quota and default container limits
      already in place.

      ## 🎯 When to use it

      Use this building block when you:
      - need a namespace to deploy a containerised application to
      - want your workspace members to manage it without cluster-wide rights

      Ordering it creates an Entra group per namespace role (`admin`, `edit`, `view`) and adds your
      workspace members to them according to their workspace role.

      ## 💡 Usage examples

      **Example 1: A dev and a prod namespace**
      Order the block twice, once as `myapp-dev` and once as `myapp-prod`.

      **Example 2: Read-only access for auditors**
      Give your auditors the workspace Reader role and they land in the namespace's `view` group, which can
      inspect workloads without changing them.

      ## 📊 Shared Responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Operate the AKS cluster and its identity | ✅ | ❌ |
      | Set up the backplane identity and permissions | ✅ | ❌ |
      | Set the namespace quota | ✅ | ❌ |
      | Choose the namespace name | ❌ | ✅ |
      | Decide who is a workspace member and with which role | ❌ | ✅ |
      | Deploy and operate workloads in the namespace | ❌ | ✅ |
    EOT
    ))
  }

  version_spec = {
    draft = var.hub.bbd_draft

    deletion_mode = "DELETE"
    runner_ref = var.building_block_runner_uuid == null ? null : {
      kind = "meshBuildingBlockRunner"
      uuid = var.building_block_runner_uuid
    }

    implementation = {
      terraform = {
        terraform_version              = "1.12.5"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/azure/aks-namespace/buildingblock"
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
      ARM_SUBSCRIPTION_ID = {
        type            = "STRING"
        display_name    = "ARM Subscription ID"
        description     = "The Azure subscription that hosts the AKS cluster."
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
      aks_cluster_name = {
        type            = "STRING"
        display_name    = "AKS Cluster Name"
        description     = "Name of the AKS cluster the namespace is created in."
        assignment_type = "STATIC"
        argument        = jsonencode(var.aks_cluster_name)
      }
      aks_resource_group_name = {
        type            = "STRING"
        display_name    = "AKS Resource Group"
        description     = "Resource group of the AKS cluster."
        assignment_type = "STATIC"
        argument        = jsonencode(var.aks_resource_group_name)
      }
      workspace_identifier = {
        type            = "STRING"
        display_name    = "Workspace Identifier"
        description     = "The meshStack workspace that owns the namespace."
        assignment_type = "WORKSPACE_IDENTIFIER"
      }
      namespace_name = {
        type                           = "STRING"
        display_name                   = "Namespace Name"
        description                    = "Name of the Kubernetes namespace, e.g. 'myapp-dev'."
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[a-z0-9]([-a-z0-9]{0,61}[a-z0-9])?$"
        validation_regex_error_message = "Lowercase letters, digits and dashes only, at most 63 characters, starting and ending with a letter or digit."
      }
      group_name_prefix = {
        type            = "STRING"
        display_name    = "Group Name Prefix"
        description     = "Prepended to the display names of the Entra groups created for the namespace."
        assignment_type = "STATIC"
        argument        = jsonencode(var.azure_group_name_prefix)
      }
      user_lookup_attribute = {
        type            = "STRING"
        display_name    = "User Lookup Attribute"
        description     = "Directory attribute used to look up users. 'email' matches the SMTP address; 'upn' matches the User Principal Name."
        assignment_type = "STATIC"
        argument        = jsonencode(var.azure_user_lookup_attribute)
      }
      role_mapping = {
        type            = "CODE"
        display_name    = "Role Mapping"
        description     = "Maps meshStack workspace roles to the namespace roles admin, edit and view."
        assignment_type = "STATIC"
        # jsonencode twice is correct for structured inputs, see https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block_definition#argument-1
        argument = jsonencode(jsonencode(var.workspace_role_mapping))
      }
      resource_quota = {
        type            = "CODE"
        display_name    = "Resource Quota"
        description     = "ResourceQuota applied to the namespace: requests_cpu, requests_memory, limits_cpu, limits_memory and pods."
        assignment_type = "STATIC"
        # jsonencode twice is correct for structured inputs, see https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block_definition#argument-1
        argument = jsonencode(jsonencode(var.resource_quota))
      }
      users = {
        type            = "CODE"
        display_name    = "Users"
        description     = "Workspace members with their roles. Injected automatically by meshStack."
        assignment_type = "USER_PERMISSIONS"
      }
    }

    outputs = {
      namespace_name = {
        type            = "STRING"
        display_name    = "Namespace Name"
        description     = "Name of the created Kubernetes namespace."
        assignment_type = "NONE"
      }
      cluster_name = {
        type            = "STRING"
        display_name    = "AKS Cluster Name"
        description     = "Name of the AKS cluster hosting the namespace."
        assignment_type = "NONE"
      }
      cluster_resource_group_name = {
        type            = "STRING"
        display_name    = "AKS Resource Group"
        description     = "Resource group of the AKS cluster hosting the namespace."
        assignment_type = "NONE"
      }
      group_object_ids = {
        type            = "STRING"
        display_name    = "Group Object IDs"
        description     = "JSON map of namespace role to the Entra group created for it."
        assignment_type = "NONE"
      }
      unresolved_users = {
        type            = "STRING"
        display_name    = "Unresolved Users"
        description     = "JSON list of workspace members not found in the directory, and so not added to any group."
        assignment_type = "NONE"
      }
      summary = {
        type            = "STRING"
        display_name    = "Summary"
        description     = "Markdown summary shown in meshPanel after the run."
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
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.64.0, < 5.0.0"
    }
  }
}
