resource "meshstack_platform" "this" {
  metadata = {
    name               = var.platform_name
    owned_by_workspace = var.owning_workspace_identifier
  }

  spec = {
    display_name      = var.platform_display_name
    description       = var.platform_description
    endpoint          = var.kube_host
    documentation_url = var.documentation_url
    support_url       = var.support_url

    location_ref = {
      name = var.location_identifier
    }

    # meshStack operators change publication state and access restriction after the first
    # deployment, so the lifecycle block below keeps Terraform from resetting them.
    availability = {
      publication_state        = "PUBLISHED"
      restriction              = "PUBLIC"
      restricted_to_workspaces = []
    }

    contributing_workspaces = []

    config = {
      kubernetes = {
        base_url               = var.kube_host
        disable_ssl_validation = var.disable_ssl_validation

        replication = {
          client_config = {
            access_token = {
              secret_value = local.replicator_token
            }
          }
          namespace_name_pattern = var.namespace_name_pattern
        }

        metering = var.metering_enabled ? {
          client_config = {
            access_token = {
              secret_value = local.metering_token
            }
          }
          processing = {
            compact_timelines_after_days = var.metering_processing.compact_timelines_after_days
            delete_raw_data_after_days   = var.metering_processing.delete_raw_data_after_days
          }
        } : null
      }
    }

    quota_definitions = var.quota_definitions
  }

  lifecycle {
    ignore_changes = [spec.availability]
  }
}
