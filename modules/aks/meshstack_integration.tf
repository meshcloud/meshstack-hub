terraform {
  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = "~> 0.18.2"
    }
  }
}

provider "meshstack" {
  # Configure meshStack API credentials here or use environment variables.
  # endpoint  = "https://api.my.meshstack.io"
  # apikey    = "00000000-0000-0000-0000-000000000000"
  # apisecret = "uFOu4OjbE4JiewPxezDuemSP3DUrCYmw"
}

# Configure required providers
provider "azurerm" {
  features {}
  subscription_id = local.aks_subscription_id
}

provider "kubernetes" {
}

# Change these values according to your AKS and meshStack setup.
locals {
  # Existing AKS cluster config.
  aks_base_url        = "https://my-cluster.abc.europe.azmk8s.io"
  aks_subscription_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  aks_cluster_name    = "my-cluster"
  aks_resource_group  = "my-resource-group"

  # meshStack workspace that will manage the platform
  aks_platform_workspace  = "platform-aks"
  aks_platform_identifier = "aks"
  aks_location_identifier = "global"
}

# For workload identity federation config
data "meshstack_integrations" "integrations" {}

# For Entra tenant name
data "azuread_domains" "aad_domains" {
  only_initial = true
}

module "aks_meshplatform" {
  source  = "meshcloud/meshplatform/aks"
  version = "~> 0.2.0"

  namespace = "meshcloud"
  scope     = local.aks_subscription_id

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
    name               = local.aks_platform_identifier
    owned_by_workspace = local.aks_platform_workspace
  }

  spec = {
    description  = "Azure Kubernetes Service (AKS). Create a k8s namespace in our AKS cluster."
    display_name = "AKS Namespace"
    endpoint     = local.aks_base_url

    location_ref = {
      name = local.aks_location_identifier
    }

    # This platform is available to all users
    availability = {
      restriction       = "PUBLIC"
      publication_state = "PUBLISHED"
    }

    config = {
      aks = {
        base_url               = local.aks_base_url
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
            plaintext = module.aks_meshplatform.replicator_token
          }

          group_name_pattern     = "aks-#{workspaceIdentifier}.#{projectIdentifier}-#{platformGroupAlias}"
          namespace_name_pattern = "#{workspaceIdentifier}-#{projectIdentifier}"

          user_lookup_strategy       = "UserByMailLookupStrategy"
          send_azure_invitation_mail = false

          aks_subscription_id = local.aks_subscription_id
          aks_cluster_name    = local.aks_cluster_name
          aks_resource_group  = local.aks_resource_group

        }

        metering = {
          client_config = {
            access_token = {
              plaintext = module.aks_meshplatform.metering_token
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
    name               = "${local.aks_platform_identifier}-default"
    owned_by_workspace = local.aks_platform_workspace
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
