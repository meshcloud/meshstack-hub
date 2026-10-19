variable "azure_tenant_id" {
  type        = string
  description = "Azure Entra tenant ID the namespace building block authenticates against."
}

variable "azure_subscription_id" {
  type        = string
  description = "Azure subscription that hosts the AKS cluster."
}

variable "azure_scope" {
  type        = string
  description = "Azure management group or subscription scope the namespace backplane's custom role is assignable at. Must contain the AKS cluster."
}

variable "azure_location" {
  type        = string
  description = "Azure region for the backplane resources (managed identity, container registry)."
}

variable "azure_user_lookup_attribute" {
  type        = string
  default     = "email"
  description = "Directory attribute used to match meshStack workspace members to Entra users. 'email' suits B2B guests, 'upn' only works for members native to the tenant."
}

variable "azure_group_name_prefix" {
  type        = string
  default     = ""
  description = "Prepended to the display names of the Entra groups created per namespace. Leave empty to omit."
}

variable "aks_cluster_name" {
  type        = string
  description = "Name of the existing AKS cluster. It must be Entra-integrated with Azure RBAC for Kubernetes authorization enabled."
}

variable "aks_resource_group_name" {
  type        = string
  description = "Resource group of the AKS cluster."
}

variable "acr_id" {
  type        = string
  default     = null
  description = "Resource ID of an existing Azure Container Registry. When set, the cluster's kubelet identity gets AcrPull on it."
}

variable "workspace_role_mapping" {
  type = map(string)
  default = {
    "Workspace Owner"   = "admin"
    "Workspace Manager" = "edit"
    "Workspace Member"  = "view"
  }
  description = "Maps a meshStack workspace role name to the namespace role (admin, edit or view) its members get in every namespace."
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
  description = "ResourceQuota applied to every namespace the platform creates."
}

variable "github" {
  type = object({
    org                 = string
    app_id              = string
    app_installation_id = string
    app_pem_file        = string
  })
  sensitive   = true
  description = "GitHub organization and the GitHub App credentials the GitHub Terraform provider authenticates with. app_pem_file is the raw PEM private key content."
}

variable "github_template_repo_path" {
  type        = string
  description = "Template repository (owner/repo) every application repository is created from."
  default     = "likvid-bank/aks-starterkit-template"
}

variable "apps_base_domain" {
  type        = string
  description = "Base domain application URLs are built under (example: `apps.example.com`)."
  default     = "likvid-k8s.msh.host"
}

variable "namespace_backplane_name" {
  type        = string
  default     = "azure-kubernetes-namespace"
  description = "Name of the namespace backplane's resource group, managed identity and custom role. The role definition name is unique per Entra tenant, so set a different value when another deployment already uses this one. Must match ^[-a-z0-9]+$."
}

variable "connector_backplane_name" {
  type        = string
  default     = "azure-kubernetes-connector"
  description = "Prefix for the resources the GitHub Actions connector's backplane creates (resource group, app registration, container registry). The registry name is this value without dashes, so it must be globally unique across Azure, 5 to 50 lowercase alphanumerics and dashes."
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
  description = "Shared meshStack context. Tags are optional and propagated to every building block definition."
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
  `bbd_draft`: If true, the building block definition versions are kept in draft mode.
  EOT
}

output "building_block_definitions" {
  description = "The building block definitions this architecture registers, by role. The starterkit is the one application teams order."
  value = {
    starterkit       = module.starterkit.building_block_definition
    namespace        = module.aks_namespace.building_block_definition
    repository       = module.github_repository.building_block_definition
    github_connector = module.github_connector.building_block_definition
  }
}

module "aks_namespace" {
  source = "github.com/meshcloud/meshstack-hub//modules/aks/namespace?ref=${var.hub.git_ref}"

  azure_tenant_id             = var.azure_tenant_id
  azure_subscription_id       = var.azure_subscription_id
  azure_scope                 = var.azure_scope
  azure_location              = var.azure_location
  azure_user_lookup_attribute = var.azure_user_lookup_attribute
  azure_group_name_prefix     = var.azure_group_name_prefix
  aks_cluster_name            = var.aks_cluster_name
  aks_resource_group_name     = var.aks_resource_group_name
  acr_id                      = var.acr_id
  backplane_name              = var.namespace_backplane_name
  workspace_role_mapping      = var.workspace_role_mapping
  resource_quota              = var.resource_quota
  notification_subscribers    = var.notification_subscribers

  meshstack = var.meshstack
  hub       = var.hub
}

module "github_repository" {
  source = "github.com/meshcloud/meshstack-hub//modules/github/repository?ref=${var.hub.git_ref}"

  github                   = var.github
  notification_subscribers = var.notification_subscribers

  meshstack = var.meshstack
  hub       = var.hub
}

# Mints the cluster-facing credentials the connector hands to GitHub Actions: a kubeconfig stub and
# the container registry the pipelines push to. Its providers (azurerm, azuread, kubernetes) are the
# caller's to configure, see the readme.
module "github_connector_backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/aks/github-connector/backplane?ref=${var.hub.git_ref}"

  resource_prefix = var.connector_backplane_name

  aks = {
    cluster_name        = var.aks_cluster_name
    resource_group_name = var.aks_resource_group_name
  }
  acr = {
    location = var.azure_location
  }
}

module "github_connector" {
  source = "github.com/meshcloud/meshstack-hub//modules/aks/github-connector?ref=${var.hub.git_ref}"

  github = {
    repo_definition_uuid = module.github_repository.building_block_definition.uuid
    org                  = var.github.org
    app_id               = var.github.app_id
    app_installation_id  = var.github.app_installation_id
    app_pem_file         = var.github.app_pem_file
  }
  aks = {
    namespace_definition_uuid  = module.aks_namespace.building_block_definition.uuid
    connector_config_tf_base64 = base64encode(module.github_connector_backplane.config_tf)
  }
  notification_subscribers = var.notification_subscribers

  meshstack = var.meshstack
  hub       = var.hub
}

module "starterkit" {
  source = "github.com/meshcloud/meshstack-hub//modules/aks/starterkit?ref=${var.hub.git_ref}"

  building_block_definition_version_refs = {
    "git-repository"           = module.github_repository.building_block_definition.version_ref
    "aks-namespace"            = module.aks_namespace.building_block_definition.version_ref
    "github-actions-connector" = module.github_connector.building_block_definition.version_ref
  }
  github_org                = var.github.org
  github_template_repo_path = var.github_template_repo_path
  apps_base_domain          = var.apps_base_domain
  notification_subscribers  = var.notification_subscribers

  meshstack = var.meshstack
  hub       = var.hub
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
      version = ">= 4.64.0"
    }
  }
}

provider "azurerm" {
  features {}
}
