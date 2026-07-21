variable "gcp_project_id" {
  type        = string
  description = "GCP project ID where meshStack service accounts and WIF resources will be created. This is typically a dedicated 'meshstack-root' project."
}

variable "gcp_org_id" {
  type        = string
  description = "GCP organization ID. meshStack manages projects and IAM within this organization."
}

variable "gcp_billing_org_id" {
  type        = string
  default     = null
  description = "GCP organization ID that holds the billing account. Defaults to gcp_org_id when null (most common case)."
}

variable "gcp_billing_account_id" {
  type        = string
  description = "GCP billing account ID to associate with all GCP projects managed by meshStack."
}

variable "gcp_folder_id" {
  type        = string
  description = "Default GCP folder ID for the default landing zone. The replicator service account receives permissions on this folder."
}

variable "gcp_domain" {
  type        = string
  description = "Google Workspace / Cloud Identity domain for groups managed by meshStack (e.g. 'example.com')."
}

variable "gcp_customer_id" {
  type        = string
  description = "Google Customer ID for your Google Workspace / Cloud Identity account. Typically starts with 'C' (e.g. 'C01234567')."
}

variable "gcp_billing_export_project_id" {
  type        = string
  description = "GCP project ID where the BigQuery billing export table resides."
}

variable "gcp_billing_export_dataset_id" {
  type        = string
  description = "BigQuery dataset ID containing the GCP Cloud Billing BigQuery export."
}

variable "gcp_billing_export_table_id" {
  type        = string
  description = "BigQuery table ID containing the GCP Cloud Billing BigQuery export."
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    platform_name               = optional(string, "gcp")
    location_name               = optional(string, "global")
    tags                        = optional(map(list(string)), {})
  })
  description = "meshStack ownership and naming settings for this platform integration. Tags are propagated to landing zone metadata."
}

data "meshstack_integrations" "integrations" {}

locals {
  billing_org_id = coalesce(var.gcp_billing_org_id, var.gcp_org_id)
}

# Creates required GCP service accounts and WIF resources for meshStack
module "this" {
  source = "github.com/meshcloud/terraform-gcp-meshplatform?ref=0.3.0"

  project_id     = var.gcp_project_id
  org_id         = var.gcp_org_id
  billing_org_id = local.billing_org_id

  landing_zone_folder_ids = [var.gcp_folder_id]

  billing_account_id = var.gcp_billing_account_id

  cloud_billing_export_project_id = var.gcp_billing_export_project_id
  cloud_billing_export_dataset_id = var.gcp_billing_export_dataset_id
  cloud_billing_export_table_id   = var.gcp_billing_export_table_id

  service_account_keys         = false # Use only workload identity federation
  carbon_export_module_enabled = false

  # Required by the module even when carbon_export_module_enabled = false
  cloud_carbon_export_project_id = var.gcp_billing_export_project_id
  cloud_carbon_export_dataset_id = var.gcp_billing_export_dataset_id

  workload_identity_federation = {
    workload_identity_pool_identifier = "meshstack-platform-pool"
    issuer                            = data.meshstack_integrations.integrations.workload_identity_federation.replicator.issuer
    audience                          = data.meshstack_integrations.integrations.workload_identity_federation.replicator.gcp.audience
    replicator_subject                = data.meshstack_integrations.integrations.workload_identity_federation.replicator.subject
    kraken_subject                    = data.meshstack_integrations.integrations.workload_identity_federation.metering.subject
  }
}

# Configure meshStack platform
resource "meshstack_platform" "this" {
  metadata = {
    name               = var.meshstack.platform_name
    owned_by_workspace = var.meshstack.owning_workspace_identifier
  }

  spec = {
    description  = "Google Cloud Platform. Create a GCP project."
    display_name = "GCP Project"
    endpoint     = "https://console.cloud.google.com"

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
      gcp = {
        replication = {
          service_account = {
            workload_identity = {
              audience              = data.meshstack_integrations.integrations.workload_identity_federation.replicator.gcp.audience
              service_account_email = module.this.replicator_sa_email
            }
          }

          domain      = var.gcp_domain
          customer_id = var.gcp_customer_id

          project_name_pattern = "#{workspaceIdentifier}.#{projectIdentifier}"
          project_id_pattern   = "#{workspaceIdentifier}-#{projectIdentifier}"
          group_name_pattern   = "#{workspaceIdentifier}.#{projectIdentifier}-#{platformGroupAlias}"

          billing_account_id                   = var.gcp_billing_account_id
          user_lookup_strategy                 = "email"
          allow_hierarchical_folder_assignment = false
          skip_user_group_permission_cleanup   = false

          gcp_role_mappings = [
            {
              gcp_role = "roles/editor"
              project_role_ref = {
                name = "admin"
              }
            },
            {
              gcp_role = "roles/editor"
              project_role_ref = {
                name = "user"
              }
            },
            {
              gcp_role = "roles/viewer"
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
          service_account = {
            workload_identity = {
              audience              = data.meshstack_integrations.integrations.workload_identity_federation.metering.gcp.audience
              service_account_email = module.this.kraken_sa_email
            }
          }

          bigquery_table        = module.this.cloud_billing_export_table_name
          partition_time_column = "usage_start_time"

          processing = {}
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [spec.availability]
  }
}

resource "meshstack_landingzone" "gcp_default" {
  metadata = {
    name               = "${var.meshstack.platform_name}-lz"
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name                  = "GCP Default"
    description                   = "Default GCP landing zone"
    automate_deletion_approval    = true
    automate_deletion_replication = true

    platform_ref = {
      uuid = meshstack_platform.this.metadata.uuid
    }

    platform_properties = {
      gcp = {
        gcp_folder_id     = var.gcp_folder_id
        gcp_role_mappings = []
      }
    }
  }
}

terraform {
  required_version = ">= 1.12.0"

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.23.0"
    }
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}
