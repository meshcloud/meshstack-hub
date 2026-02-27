variable "manage_meshstack_platform" {
  description = "Whether to create meshstack_platform and meshstack_landingzone resources. Set to false for infra-only deployments."
  type        = bool
  default     = true
}

variable "aks" {
  description = "AKS cluster infrastructure and service principal configuration."
  type = object({
    base_url        = string
    subscription_id = string
    cluster_name    = string
    resource_group  = string

    # meshcloud/meshplatform/aks module config
    service_principal_name = string
    namespace              = optional(string, "meshcloud")
    create_password        = optional(bool, false)
    workload_identity_federation = optional(object({
      issuer         = string
      access_subject = string
    }))
    replicator_enabled = optional(bool, true)
    replicator_additional_rules = optional(list(object({
      api_groups        = list(string)
      resources         = list(string)
      verbs             = list(string)
      resource_names    = optional(list(string))
      non_resource_urls = optional(list(string))
    })), [])
    existing_clusterrole_name_replicator = optional(string, "")
    kubernetes_name_suffix_replicator    = optional(string, "")
    metering_enabled                     = optional(bool, true)
    metering_additional_rules = optional(list(object({
      api_groups        = list(string)
      resources         = list(string)
      verbs             = list(string)
      resource_names    = optional(list(string))
      non_resource_urls = optional(list(string))
    })), [])
  })
}

variable "meshstack_platform" {
  description = "meshStack platform and landing zone registration. Required when manage_meshstack_platform is true."
  default     = null
  type = object({
    owning_workspace_identifier = string
    platform_identifier         = string
    location_identifier         = optional(string, "global")

    display_name      = optional(string, "AKS Namespace")
    description       = optional(string, "Azure Kubernetes Service (AKS). Create a k8s namespace in our AKS cluster.")
    documentation_url = optional(string)
    support_url       = optional(string)

    disable_ssl_validation     = optional(bool, true)
    group_name_pattern         = optional(string, "aks-#{workspaceIdentifier}.#{projectIdentifier}-#{platformGroupAlias}")
    namespace_name_pattern     = optional(string, "#{workspaceIdentifier}-#{projectIdentifier}")
    user_lookup_strategy       = optional(string, "UserByMailLookupStrategy")
    send_azure_invitation_mail = optional(bool, false)
    redirect_url               = optional(string)

    quota_definitions = optional(list(object({
      quota_key               = string
      label                   = string
      description             = string
      unit                    = string
      max_value               = number
      min_value               = number
      auto_approval_threshold = number
    })), [])

    landing_zone = optional(object({
      name                          = optional(string)
      display_name                  = optional(string, "AKS Default")
      description                   = optional(string, "Default AKS landing zone")
      automate_deletion_approval    = optional(bool, true)
      automate_deletion_replication = optional(bool, true)
      tags                          = optional(map(list(string)), {})
      quotas = optional(list(object({
        key   = string
        value = number
      })), [])
      kubernetes_role_mappings = optional(list(object({
        platform_roles   = list(string)
        project_role_ref = object({ name = string })
        })), [
        { platform_roles = ["admin"], project_role_ref = { name = "admin" } },
        { platform_roles = ["edit"], project_role_ref = { name = "user" } },
        { platform_roles = ["view"], project_role_ref = { name = "reader" } }
      ])
    }), {})
  })
}

terraform {
  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.19.3"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 2.0.0"
    }
  }
}

locals {
  landing_zone_name = var.manage_meshstack_platform ? coalesce(
    var.meshstack_platform.landing_zone.name,
    "${var.meshstack_platform.platform_identifier}-default"
  ) : null
}

module "aks_meshplatform" {
  source  = "meshcloud/meshplatform/aks"
  version = "~> 0.2.0"

  namespace = var.aks.namespace
  scope     = var.aks.subscription_id

  service_principal_name       = var.aks.service_principal_name
  create_password              = var.aks.create_password
  workload_identity_federation = var.aks.workload_identity_federation

  replicator_enabled                   = var.aks.replicator_enabled
  replicator_additional_rules          = var.aks.replicator_additional_rules
  existing_clusterrole_name_replicator = var.aks.existing_clusterrole_name_replicator
  kubernetes_name_suffix_replicator    = var.aks.kubernetes_name_suffix_replicator

  metering_enabled          = var.aks.metering_enabled
  metering_additional_rules = var.aks.metering_additional_rules
}

# For Entra tenant name
data "azuread_domains" "aad_domains" {
  only_initial = true
}

resource "meshstack_platform" "aks" {
  count = var.manage_meshstack_platform ? 1 : 0

  metadata = {
    name               = var.meshstack_platform.platform_identifier
    owned_by_workspace = var.meshstack_platform.owning_workspace_identifier
  }

  spec = {
    description       = var.meshstack_platform.description
    display_name      = var.meshstack_platform.display_name
    documentation_url = var.meshstack_platform.documentation_url
    support_url       = var.meshstack_platform.support_url
    endpoint          = var.aks.base_url

    location_ref = {
      name = var.meshstack_platform.location_identifier
    }

    availability = {
      restriction       = "PUBLIC"
      publication_state = "PUBLISHED"
    }

    config = {
      aks = {
        base_url               = var.aks.base_url
        disable_ssl_validation = var.meshstack_platform.disable_ssl_validation

        replication = {
          service_principal = {
            entra_tenant = data.azuread_domains.aad_domains.domains[0].domain_name
            client_id    = module.aks_meshplatform.replicator_service_principal.Application_Client_ID
            object_id    = module.aks_meshplatform.replicator_service_principal.Enterprise_Application_Object_ID

            auth = {
              credential = null
            }
          }

          access_token = {
            secret_value   = module.aks_meshplatform.replicator_token
            secret_version = sha256(module.aks_meshplatform.replicator_token)
          }

          group_name_pattern     = var.meshstack_platform.group_name_pattern
          namespace_name_pattern = var.meshstack_platform.namespace_name_pattern

          user_lookup_strategy       = var.meshstack_platform.user_lookup_strategy
          send_azure_invitation_mail = var.meshstack_platform.send_azure_invitation_mail

          aks_subscription_id = var.aks.subscription_id
          aks_cluster_name    = var.aks.cluster_name
          aks_resource_group  = var.aks.resource_group
          redirect_url        = var.meshstack_platform.redirect_url
        }

        metering = {
          client_config = {
            access_token = {
              secret_value   = module.aks_meshplatform.metering_token
              secret_version = sha256(module.aks_meshplatform.metering_token)
            }
          }
          processing = {}
        }
      }
    }

    quota_definitions = var.meshstack_platform.quota_definitions
  }
}

resource "meshstack_landingzone" "aks_default" {
  count = var.manage_meshstack_platform ? 1 : 0

  metadata = {
    name               = local.landing_zone_name
    owned_by_workspace = var.meshstack_platform.owning_workspace_identifier
    tags               = var.meshstack_platform.landing_zone.tags
  }

  spec = {
    description  = var.meshstack_platform.landing_zone.description
    display_name = var.meshstack_platform.landing_zone.display_name

    platform_ref = meshstack_platform.aks[0].metadata

    automate_deletion_approval    = var.meshstack_platform.landing_zone.automate_deletion_approval
    automate_deletion_replication = var.meshstack_platform.landing_zone.automate_deletion_replication

    platform_properties = {
      aks = {
        kubernetes_role_mappings = var.meshstack_platform.landing_zone.kubernetes_role_mappings
      }
    }

    quotas = var.meshstack_platform.landing_zone.quotas
  }
}

output "aks" {
  description = "AKS platform identifiers for use as var.aks in the starterkit. Null when manage_meshstack_platform is false."
  value = var.manage_meshstack_platform ? {
    full_platform_identifier     = "${meshstack_platform.aks[0].metadata.name}.${var.meshstack_platform.location_identifier}"
    landing_zone_dev_identifier  = meshstack_landingzone.aks_default[0].metadata.name
    landing_zone_prod_identifier = meshstack_landingzone.aks_default[0].metadata.name
  } : null
}

output "replicator_token" {
  description = "Replicator service account token."
  value       = module.aks_meshplatform.replicator_token
  sensitive   = true
}

output "metering_token" {
  description = "Metering service account token."
  value       = module.aks_meshplatform.metering_token
  sensitive   = true
}

output "replicator_service_principal" {
  description = "Replicator Service Principal."
  value       = module.aks_meshplatform.replicator_service_principal
  sensitive   = true
}

output "replicator_service_principal_password" {
  description = "Password for Replicator Service Principal."
  value       = module.aks_meshplatform.replicator_service_principal_password
  sensitive   = true
}
