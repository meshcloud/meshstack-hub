terraform {
  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = "~> 0.19.1"
    }
  }
}

provider "meshstack" {
  # Configure meshStack API credentials here or use environment variables.
  # endpoint  = "https://api.my.meshstack.io"
  # apikey    = "00000000-0000-0000-0000-000000000000"
  # apisecret = "uFOu4OjbE4JiewPxezDuemSP3DUrCYmw"
}

provider "azurerm" {
  features {}
  resource_provider_registrations = "none"
}

# Change these values according to your Azure and meshStack setup.
locals {
  # Azure management group which will be managed by meshStack
  azure_management_group         = "my-cloud-foundation"
  azure_administrative_unit_name = "my-administrative-unit"

  # Configure according to your Microsoft customer agreement
  mca = {
    billing_account_name   = "00000000-0000-0000-0000-000000000000:00000000-0000-0000-0000-000000000000_2018-09-30"
    billing_profile_name   = "0000-0000-000-000"
    invoice_section_name   = "0000-0000-000-000"
    service_principal_name = "my-meshstack-replicator"
  }

  # Azure subscriptions require at least one owner. This assigns the current user/service principal as owner.
  # Update this list to match your organization's ownership requirements.
  subscription_owner_object_ids = [data.azurerm_client_config.current.object_id]

  # meshStack workspace that will manage the platform
  meshstack_platform_workspace = "managed-customer"
  meshstack_platform_name      = "azure"
  meshstack_location_name      = "azure"
}

# For workload identity federation config
data "meshstack_integrations" "integrations" {}

# For Entra tenant name
data "azuread_domains" "aad_domains" {
  only_initial = true
}

# For Azure Blueprints
data "azuread_service_principal" "blueprints" {
  # Client ID is known but object id changes
  client_id = "f71766dc-90d9-4b7d-bd9d-4499c4331c3f"
}

# For current user or service principal
data "azurerm_client_config" "current" {}

# For role assignments
data "azurerm_role_definition" "contributor" {
  name = "Contributor"
}

# For role assignments
data "azurerm_role_definition" "reader" {
  name = "Reader"
}

data "azurerm_billing_mca_account_scope" "subscriptions" {
  billing_account_name = local.mca.billing_account_name
  billing_profile_name = local.mca.billing_profile_name
  invoice_section_name = local.mca.invoice_section_name
}

# Creates required resource in Azure
module "azure_meshplatform" {
  source  = "meshcloud/meshplatform/azure"
  version = "~> 0.14.0"

  replicator_enabled                = true
  replicator_service_principal_name = local.mca.service_principal_name
  replicator_custom_role_scope      = local.azure_management_group
  replicator_assignment_scopes      = [local.azure_management_group]

  can_cancel_subscriptions_in_scopes = [local.azure_management_group]
  administrative_unit_name           = local.azure_administrative_unit_name

  metering_enabled                = true
  metering_service_principal_name = "my-meshstack-metering"
  metering_assignment_scopes      = [local.azure_management_group]

  create_passwords = false # Use only workload identity federation

  workload_identity_federation = {
    issuer             = data.meshstack_integrations.integrations.workload_identity_federation.replicator.issuer
    replicator_subject = data.meshstack_integrations.integrations.workload_identity_federation.replicator.subject
    kraken_subject     = data.meshstack_integrations.integrations.workload_identity_federation.metering.subject
    mca_subject        = data.meshstack_integrations.integrations.workload_identity_federation.replicator.subject
  }

  mca = {
    billing_account_name   = local.mca.billing_account_name
    billing_profile_name   = local.mca.billing_profile_name
    invoice_section_name   = local.mca.invoice_section_name
    service_principal_name = local.mca.service_principal_name
  }
}

# Use a dedicated location for this platform
resource "meshstack_location" "azure" {
  metadata = {
    name               = local.meshstack_location_name
    owned_by_workspace = local.meshstack_platform_workspace
  }

  spec = {
    display_name = "Azure"
    description  = "Microsoft Azure"
  }
}

# Configure meshStack platform
resource "meshstack_platform" "azure" {
  metadata = {
    name               = local.meshstack_platform_name
    owned_by_workspace = local.meshstack_platform_workspace
  }

  spec = {
    description  = "Microsoft Azure. Create an Azure subscription."
    display_name = "Azure Subscription"
    endpoint     = "https://portal.azure.com"

    location_ref = meshstack_location.azure.ref

    # This platform is available to all users
    availability = {
      restriction       = "PUBLIC"
      publication_state = "PUBLISHED"
    }

    config = {
      azure = {
        entra_tenant = data.azuread_domains.aad_domains.domains[0].domain_name

        replication = {
          subscription_name_pattern = "#{workspaceIdentifier}.#{projectIdentifier}"
          update_subscription_name  = false

          group_name_pattern                 = "#{workspaceIdentifier}.#{projectIdentifier}-#{platformGroupAlias}"
          skip_user_group_permission_cleanup = false

          user_lookup_strategy = "UserByMailLookupStrategy"

          blueprint_service_principal = data.azuread_service_principal.blueprints.object_id
          blueprint_location          = "westeurope"

          service_principal = {
            client_id = module.azure_meshplatform.replicator_service_principal.Application_Client_ID
            object_id = module.azure_meshplatform.replicator_service_principal.Enterprise_Application_Object_ID

            auth = {} # workload identity federation
          }

          root_management_group                          = local.azure_management_group
          allow_hierarchical_management_group_assignment = false

          provisioning = {
            customer_agreement = {
              billing_scope        = data.azurerm_billing_mca_account_scope.subscriptions.id
              destination_entra_id = module.azure_meshplatform.azure_ad_tenant_id
              source_entra_tenant  = module.azure_meshplatform.azure_ad_tenant_id

              source_service_principal = {
                client_id = module.azure_meshplatform.replicator_service_principal.Application_Client_ID
                auth      = {} # workload identity federation
              }
              subscription_creation_error_cooldown_sec = 900
            }
            subscription_owner_object_ids = local.subscription_owner_object_ids
          }

          azure_role_mappings = [
            {
              azure_role = {
                alias = "admin"
                id    = data.azurerm_role_definition.contributor.id
              }
              project_role_ref = {
                name = "admin"
              }
            },
            {
              azure_role = {
                alias = "user"
                id    = data.azurerm_role_definition.contributor.id
              }
              project_role_ref = {
                name = "user"
              }
            },
            {
              azure_role = {
                alias = "reader"
                id    = data.azurerm_role_definition.reader.id
              }
              project_role_ref = {
                name = "reader"
              }
            },
          ]

          tenant_tags = {
            namespace_prefix = "mesh_"
            tag_mappers = [
              {
                key           = "wsid"
                value_pattern = "$${workspaceIdentifier}"
              },
            ]
          }
        }

        metering = {
          enabled = true
          service_principal = {
            client_id = module.azure_meshplatform.metering_service_principal.Application_Client_ID
            object_id = module.azure_meshplatform.metering_service_principal.Enterprise_Application_Object_ID

            auth = {} # workload identity federation
          }
          processing = {}
        }
      }
    }
  }
}

resource "meshstack_landingzone" "azure_default" {
  metadata = {
    name               = "${local.meshstack_platform_name}-default"
    owned_by_workspace = local.meshstack_platform_workspace
  }

  spec = {
    display_name                  = "Azure Default"
    description                   = "Default Azure landing zone"
    automate_deletion_approval    = true
    automate_deletion_replication = true

    platform_ref = {
      uuid = meshstack_platform.azure.metadata.uuid
    }

    platform_properties = {
      azure = {
        azure_management_group_id = local.azure_management_group

        azure_role_mappings = []
      }
    }
  }
}
