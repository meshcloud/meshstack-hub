variable "azure_management_group" {
  type        = string
  description = "Azure management group used for platform integration."
}

variable "azure_subscription_provisioning" {
  type = object({
    pre_provisioned = optional(object({
      unused_subscription_name_prefix = optional(string, "unused-")
    }))
    customer_agreement = optional(object({
      billing_account_name = string
      billing_profile_name = string
      invoice_section_name = string
    }))
  })
  nullable    = false
  description = <<-EOT
  Azure subscription provisioning model — set exactly one:
  `pre_provisioned`: meshStack assigns subscriptions from a pool of existing ones whose name starts with `unused_subscription_name_prefix` (no MCA service principal is created).
  `customer_agreement`: meshStack creates subscriptions on demand via the given MCA billing scope.
  EOT
  validation {
    condition     = (var.azure_subscription_provisioning.pre_provisioned != null) != (var.azure_subscription_provisioning.customer_agreement != null)
    error_message = "Set exactly one of pre_provisioned or customer_agreement."
  }
}

variable "azure_subscription_owner_object_ids" {
  type        = list(string)
  default     = null
  description = "Optional explicit subscription owner object IDs. If null, current principal is used."
}

variable "landing_zones" {
  type = map(object({
    management_group_id = string
    display_name        = string
    description         = optional(string, "")
  }))
  nullable    = false
  description = <<-EOT
  Landing zones to create on the Azure platform, keyed by archetype (e.g. `corp`, `online`, `sandbox`).
  Each entry points a meshStack landing zone at an existing Azure management group via `management_group_id`.
  Landing zones inherit the platform-level role mappings. The landing zone name is `<platform_name>-<key>`.
  EOT
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    platform_name               = optional(string, "azure")
    location_name               = optional(string, "global")
    tags                        = optional(map(list(string)), {})
  })
  description = "meshStack ownership and naming settings for this platform integration. `tags` are propagated to the created landing zones."
}

variable "hub" {
  type = object({
    git_ref   = optional(string, "feature/azure-platfrom-ref")
    bbd_draft = optional(bool, true)
  })
  const = true
  default = {
    git_ref   = "feature/azure-platfrom-ref"
    bbd_draft = true
  }
  description = <<-EOT
  `git_ref`: Hub release reference. Set to a tag (e.g. 'v1.2.3') or branch or commit sha of the meshstack-hub repo.
  `bbd_draft`: If true, building block definitions sourced from this integration are kept in draft mode.
  EOT
}

output "platform" {
  description = "The meshStack platform Azure subscriptions are created on. Use `uuid` as the `platform_ref` of a meshTenant."
  value = {
    uuid = meshstack_platform.azure.metadata.uuid
    name = meshstack_platform.azure.metadata.name
  }
}

output "platform_ref" {
  description = "Reference to the meshPlatform this integration creates, for compositions that create meshTenants on it."
  value = {
    uuid = meshstack_platform.azure.metadata.uuid
    kind = "meshPlatform"
  }
}

output "landingzone_names" {
  description = "meshStack landing zone names created per archetype, keyed by archetype."
  value       = { for key, lz in meshstack_landingzone.this : key => lz.metadata.name }
}

output "landingzone_refs" {
  description = "References to the created landing zones, keyed by archetype, for compositions that create meshTenants on them."
  value = {
    for key, lz in meshstack_landingzone.this : key => {
      name = lz.metadata.name
      kind = "meshLandingZone"
    }
  }
}

data "meshstack_integrations" "integrations" {}

data "azuread_domains" "aad_domains" {
  only_initial = true
}

data "azurerm_client_config" "current" {}

data "azurerm_role_definition" "contributor" {
  name = "Contributor"
}

data "azurerm_role_definition" "reader" {
  name = "Reader"
}

locals {
  customer_agreement = var.azure_subscription_provisioning.customer_agreement
  is_mca             = local.customer_agreement != null
}

data "azurerm_billing_mca_account_scope" "subscriptions" {
  count = local.is_mca ? 1 : 0

  billing_account_name = local.customer_agreement.billing_account_name
  billing_profile_name = local.customer_agreement.billing_profile_name
  invoice_section_name = local.customer_agreement.invoice_section_name
}

# Scopes are built directly from the management group name (not looked up via a data source), so they
# stay known at plan time even when the management group is created in the same run (the reference
# architecture creates it). A data source read would be deferred to apply and break the meshplatform
# module's for_each over these scopes.

# Creates required resource in Azure
module "azure_meshplatform" {
  source  = "meshcloud/meshplatform/azure"
  version = ">= 0.14.0"

  replicator_enabled                = true
  replicator_service_principal_name = "meshstack-replicator"
  replicator_custom_role_scope      = var.azure_management_group
  replicator_assignment_scopes      = [var.azure_management_group]

  can_cancel_subscriptions_in_scopes = ["/providers/Microsoft.Management/managementGroups/${var.azure_management_group}"]

  metering_enabled                = true
  metering_service_principal_name = "meshstack-metering"
  metering_assignment_scopes      = [var.azure_management_group]

  create_passwords = false # Use only workload identity federation

  workload_identity_federation = {
    issuer             = data.meshstack_integrations.integrations.workload_identity_federation.replicator.issuer
    replicator_subject = data.meshstack_integrations.integrations.workload_identity_federation.replicator.subject
    kraken_subject     = data.meshstack_integrations.integrations.workload_identity_federation.metering.subject
    mca_subject        = local.is_mca ? data.meshstack_integrations.integrations.workload_identity_federation.replicator.subject : null
  }

  # Only for the customer_agreement (MCA) model — pre-provisioned needs no MCA service principal.
  mca = local.is_mca ? {
    billing_account_name    = local.customer_agreement.billing_account_name
    billing_profile_name    = local.customer_agreement.billing_profile_name
    invoice_section_name    = local.customer_agreement.invoice_section_name
    service_principal_names = ["meshstack-mca"]
  } : null
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

          service_principal = {
            client_id = module.azure_meshplatform.replicator_service_principal.Application_Client_ID
            object_id = module.azure_meshplatform.replicator_service_principal.Enterprise_Application_Object_ID

            auth = {} # workload identity federation
          }

          allow_hierarchical_management_group_assignment = false

          # Exactly one of customer_agreement / pre_provisioned, selected by the provisioning model.
          provisioning = merge(
            {
              subscription_owner_object_ids = var.azure_subscription_owner_object_ids != null ? var.azure_subscription_owner_object_ids : [data.azurerm_client_config.current.object_id]
            },
            local.is_mca ? {
              customer_agreement = {
                billing_scope = data.azurerm_billing_mca_account_scope.subscriptions[0].id

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
              } : {
              pre_provisioned = {
                unused_subscription_name_prefix = var.azure_subscription_provisioning.pre_provisioned.unused_subscription_name_prefix
              }
            }
          )

          azure_role_mappings = [
            {
              azure_role = {
                alias = "admin"
                id    = basename(data.azurerm_role_definition.contributor.role_definition_id)
              }
              project_role_ref = {
                name = "admin"
              }
            },
            {
              azure_role = {
                alias = "user"
                id    = basename(data.azurerm_role_definition.contributor.role_definition_id)
              }
              project_role_ref = {
                name = "user"
              }
            },
            {
              azure_role = {
                alias = "reader"
                id    = basename(data.azurerm_role_definition.reader.role_definition_id)
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

  lifecycle {
    ignore_changes = [spec.availability]
  }
}

# One meshStack landing zone per archetype, each pointing at an existing Azure management group.
resource "meshstack_landingzone" "this" {
  for_each = var.landing_zones

  metadata = {
    name               = "${var.meshstack.platform_name}-${each.key}"
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name                  = each.value.display_name
    description                   = each.value.description
    automate_deletion_approval    = true
    automate_deletion_replication = true

    platform_ref = {
      uuid = meshstack_platform.azure.metadata.uuid
    }

    platform_properties = {
      azure = {
        azure_management_group_id = each.value.management_group_id

        # Landing zones inherit the platform-level role mappings.
        azure_role_mappings = []
      }
    }
  }
}

# The single fixed landing zone became a per-archetype map. A deployment that used the previous
# `azure-default` landing zone keeps it by passing a `default` archetype; `name` carries no
# RequiresReplace, so this updates in place instead of recreating the landing zone.
moved {
  from = meshstack_landingzone.azure_default
  to   = meshstack_landingzone.this["default"]
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
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 3.8"
    }
  }
}
