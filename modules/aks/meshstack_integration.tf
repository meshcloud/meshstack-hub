variable "aks_base_url" {
  type        = string
  description = "Base URL used by meshStack to reach the AKS API endpoint."
}

variable "aks_subscription_id" {
  type        = string
  description = "Azure subscription ID that hosts the AKS cluster."
}

variable "aks_cluster_name" {
  type        = string
  description = "Name of the AKS cluster."
}

variable "aks_resource_group" {
  type        = string
  description = "Resource group of the AKS cluster."
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    platform_identifier         = optional(string, "aks")
    location_identifier         = optional(string, "global")
  })
  description = "meshStack ownership and naming settings for this platform integration."
}

module "aks_meshplatform" {
  source  = "meshcloud/meshplatform/aks"
  version = "~> 0.2.0"

  namespace = "meshcloud"
  scope     = var.aks_subscription_id

  replicator_enabled     = true
  service_principal_name = "replicator-service-principal"

  metering_enabled = true

  create_password = false # Use only workload identity federation
  workload_identity_federation = {
    issuer         = data.meshstack_integrations.integrations.workload_identity_federation.replicator.issuer
    access_subject = data.meshstack_integrations.integrations.workload_identity_federation.replicator.subject
  }
}

resource "meshstack_platform" "aks" {
  metadata = {
    name               = var.meshstack.platform_identifier
    owned_by_workspace = var.meshstack.owning_workspace_identifier
  }

  spec = {
    description  = "Azure Kubernetes Service (AKS). Create a k8s namespace in our AKS cluster."
    display_name = "AKS Namespace"
    endpoint     = var.aks_base_url

    location_ref = {
      name = var.meshstack.location_identifier
    }

    # This platform is available to all users
    availability = {
      restriction       = "PUBLIC"
      publication_state = "PUBLISHED"
    }

    config = {
      aks = {
        base_url               = var.aks_base_url
        disable_ssl_validation = true # Usually the case for Kubernetes clusters

        replication = {

          service_principal = {
            entra_tenant = data.azuread_domains.aad_domains.domains[0].domain_name
            client_id    = module.aks_meshplatform.replicator_service_principal.Application_Client_ID
            object_id    = module.aks_meshplatform.replicator_service_principal.Enterprise_Application_Object_ID

            # No credential -> use workload identity federation
            auth = {
              credential = null
            }
          }

          # Direct k8s access does not use workload identity federation
          access_token = {
            secret_value = module.aks_meshplatform.replicator_token
            # Use this to detect secret changes. Unfortunately, kubernets TF provider does not support ephemeral resources at the moment.
            secret_version = sha256(module.aks_meshplatform.replicator_token)
          }

          group_name_pattern     = "aks-#{workspaceIdentifier}.#{projectIdentifier}-#{platformGroupAlias}"
          namespace_name_pattern = "#{workspaceIdentifier}-#{projectIdentifier}"

          user_lookup_strategy       = "UserByMailLookupStrategy"
          send_azure_invitation_mail = false

          aks_subscription_id = var.aks_subscription_id
          aks_cluster_name    = var.aks_cluster_name
          aks_resource_group  = var.aks_resource_group

        }

        metering = {
          client_config = {
            access_token = {
              secret_value = module.aks_meshplatform.metering_token
              # Use this to detect secret changes. Unfortunately, kubernets TF provider does not support ephemeral resources at the moment.
              secret_version = sha256(module.aks_meshplatform.metering_token)
            }
          }
          processing = {}
        }
      }
    }
  }
}

resource "meshstack_landingzone" "aks_default" {
  metadata = {
    name               = "${var.meshstack.platform_identifier}-default"
    owned_by_workspace = var.meshstack.owning_workspace_identifier
  }

  spec = {
    description  = "Default AKS landing zone"
    display_name = "AKS Default"

    platform_ref = meshstack_platform.aks.metadata

    automate_deletion_approval    = true
    automate_deletion_replication = true

    platform_properties = {
      aks = {
        kubernetes_role_mappings = [
          {
            platform_roles = [
              "admin"
            ]
            project_role_ref = {
              name = "admin"
            }
          },
          {
            platform_roles = [
              "edit"
            ]
            project_role_ref = {
              name = "user"
            }
          },
          {
            platform_roles = [
              "view"
            ]
            project_role_ref = {
              name = "reader"
            }
          }
        ]
      }
    }
  }
}

data "meshstack_integrations" "integrations" {}

data "azuread_domains" "aad_domains" {
  only_initial = true
}

terraform {
  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = "~> 0.20.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.8"
    }
  }
}
