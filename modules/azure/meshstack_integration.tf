variable "azure_management_group" {
  type        = string
  description = "Azure management group used for platform integration."
}

variable "azure_billing_account_name" {
  type        = string
  description = "MCA billing account name."
}

variable "azure_billing_profile_name" {
  type        = string
  description = "MCA billing profile name."
}

variable "azure_invoice_section_name" {
  type        = string
  description = "MCA invoice section name."
}

variable "azure_subscription_owner_object_ids" {
  type        = list(string)
  default     = null
  description = "Optional explicit subscription owner object IDs. If null, current principal is used."
}

variable "azure_blueprint_service_principal_client_id" {
  type        = string
  default     = "f71766dc-90d9-4b7d-bd9d-4499c4331c3f"
  description = "Client ID of the Azure Blueprints service principal."
}

variable "azure_blueprint_location" {
  type        = string
  default     = "westeurope"
  description = "Azure region used for Blueprints."
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    platform_name               = optional(string, "azure")
    location_name               = optional(string, "global")
  })
  description = "meshStack ownership and naming settings for this platform integration."
}

data "meshstack_integrations" "integrations" {}

data "azuread_domains" "aad_domains" {
  only_initial = true
}

data "azuread_service_principal" "blueprints" {
  # Client ID is known but object id changes
  client_id = var.azure_blueprint_service_principal_client_id
}

data "azurerm_client_config" "current" {}

data "azurerm_role_definition" "contributor" {
  name = "Contributor"
}

data "azurerm_role_definition" "reader" {
  name = "Reader"
}

data "azurerm_billing_mca_account_scope" "subscriptions" {
  billing_account_name = var.azure_billing_account_name
  billing_profile_name = var.azure_billing_profile_name
  invoice_section_name = var.azure_invoice_section_name
}

data "azurerm_management_group" "parent" {
  name = var.azure_management_group
}

# Creates required resource in Azure
module "azure_meshplatform" {
  source  = "meshcloud/meshplatform/azure"
  version = "~> 0.14.0"

  replicator_enabled                = true
  replicator_service_principal_name = "meshstack-replicator"
  replicator_custom_role_scope      = data.azurerm_management_group.parent.name
  replicator_assignment_scopes      = [data.azurerm_management_group.parent.name]

  can_cancel_subscriptions_in_scopes = [data.azurerm_management_group.parent.id]

  metering_enabled                = true
  metering_service_principal_name = "meshstack-metering"
  metering_assignment_scopes      = [data.azurerm_management_group.parent.name]

  create_passwords = false # Use only workload identity federation

  workload_identity_federation = {
    issuer             = data.meshstack_integrations.integrations.workload_identity_federation.replicator.issuer
    replicator_subject = data.meshstack_integrations.integrations.workload_identity_federation.replicator.subject
    kraken_subject     = data.meshstack_integrations.integrations.workload_identity_federation.metering.subject
    mca_subject        = data.meshstack_integrations.integrations.workload_identity_federation.replicator.subject
  }

  mca = {
    billing_account_name    = var.azure_billing_account_name
    billing_profile_name    = var.azure_billing_profile_name
    invoice_section_name    = var.azure_invoice_section_name
    service_principal_names = ["meshstack-mca"]
  }
}

# Configure meshStack platform
resource "meshstack_platform" "azure" {
  metadata = {
    name               = var.meshstack.platform_name
    owned_by_workspace = var.meshstack.owning_workspace_identifier
  }

  spec = {
    description  = "Microsoft Azure. Create an Azure subscription."
    display_name = "Azure Subscription"
    endpoint     = "https://portal.azure.com"

    location_ref = {
      name = var.meshstack.location_name
    }

    # To make this platform visible and accessible to all users, you must request publishing
    # it through the meshStack panel.
    availability = {
      restriction              = "PRIVATE"
      publication_state        = "UNPUBLISHED"
      restricted_to_workspaces = [var.meshstack.owning_workspace_identifier]
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
          blueprint_location          = var.azure_blueprint_location

          service_principal = {
            client_id = module.azure_meshplatform.replicator_service_principal.Application_Client_ID
            object_id = module.azure_meshplatform.replicator_service_principal.Enterprise_Application_Object_ID

            auth = {} # workload identity federation
          }

          allow_hierarchical_management_group_assignment = false

          provisioning = {
            customer_agreement = {
              billing_scope = data.azurerm_billing_mca_account_scope.subscriptions.id

              # This assumes the simple case where subscriptions are created in the same Entra tenant
              # that meshStack is managing (source == destination). For cross-tenant setups, set these
              # to the respective source and destination tenant IDs.
              source_entra_tenant  = module.azure_meshplatform.azure_ad_tenant_id
              destination_entra_id = module.azure_meshplatform.azure_ad_tenant_id

              source_service_principal = {
                client_id = module.azure_meshplatform.mca_service_principal["meshstack-mca"].Application_Client_ID
                auth      = {} # workload identity federation
              }
              subscription_creation_error_cooldown_sec = 900
            }
            subscription_owner_object_ids = var.azure_subscription_owner_object_ids != null ? var.azure_subscription_owner_object_ids : [data.azurerm_client_config.current.object_id]
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
    name               = "${var.meshstack.platform_name}-default"
    owned_by_workspace = var.meshstack.owning_workspace_identifier
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
        azure_management_group_id = var.azure_management_group

        azure_role_mappings = []
      }
    }
  }
}

terraform {
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
