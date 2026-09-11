# ── meshStack SKE platform ──
# Wired to the cluster via its API endpoint and the replication/metering tokens the platform-services
# building block created in-cluster.
resource "meshstack_platform" "ske" {
  metadata = {
    name               = local.platform_identifier
    owned_by_workspace = var.workspace
  }

  spec = {
    display_name      = "Kubernetes namespace on SKE (${local.platform_identifier})"
    description       = "Provides a Kubernetes namespace on STACKIT Kubernetes Engine (SKE)."
    endpoint          = local.cluster_kube_host
    documentation_url = ""
    support_url       = ""

    location_ref = {
      name = local.location_name
    }

    availability = {
      publication_state        = "PUBLISHED"
      restriction              = "PUBLIC"
      restricted_to_workspaces = []
    }

    contributing_workspaces = []

    config = {
      kubernetes = {
        base_url               = local.cluster_kube_host
        disable_ssl_validation = true

        replication = {
          client_config = {
            access_token = {
              secret_value = local.replicator_token
            }
          }
          namespace_name_pattern = "#{workspaceIdentifier}-#{projectIdentifier}"
        }

        metering = {
          client_config = {
            access_token = {
              secret_value = local.metering_token
            }
          }
          processing = {
            compact_timelines_after_days = 30
            delete_raw_data_after_days   = 65
          }
        }
      }
    }

    # CPU in millicores (m), memory in mebibytes (Mi) so values stay whole integers.
    quota_definitions = [
      {
        quota_key               = "limits.cpu"
        label                   = "CPU limit"
        description             = "The sum of CPU limits across all pods in a non-terminal state cannot exceed this value."
        unit                    = "m"
        min_value               = 0
        max_value               = 1000
        auto_approval_threshold = 1000
      },
      {
        quota_key               = "requests.cpu"
        label                   = "CPU requests"
        description             = "The sum of CPU requests across all pods in a non-terminal state cannot exceed this value."
        unit                    = "m"
        min_value               = 0
        max_value               = 1000
        auto_approval_threshold = 500
      },
      {
        quota_key               = "limits.memory"
        label                   = "Memory limit"
        description             = "The sum of memory limits across all pods in a non-terminal state cannot exceed this value."
        unit                    = "Mi"
        min_value               = 0
        max_value               = 1024
        auto_approval_threshold = 1024
      },
      {
        quota_key               = "requests.memory"
        label                   = "Memory requests"
        description             = "The sum of memory requests across all pods in a non-terminal state cannot exceed this value."
        unit                    = "Mi"
        min_value               = 0
        max_value               = 1024
        auto_approval_threshold = 512
      },
      {
        quota_key               = "requests.storage"
        label                   = "Total Storage Requests"
        description             = "Across all persistent volume claims, the sum of storage requests cannot exceed this value."
        unit                    = "Gi"
        min_value               = 0
        max_value               = 5
        auto_approval_threshold = 2
      },
      {
        quota_key               = "persistentvolumeclaims"
        label                   = "Persistent Volume Claims"
        description             = "The total number of PersistentVolumeClaims that can exist in the namespace."
        unit                    = ""
        min_value               = 0
        max_value               = 4
        auto_approval_threshold = 2
      },
    ]
  }

  # meshStack may reconcile availability out of band; ignore drift so applies stay clean.
  lifecycle {
    ignore_changes = [spec.availability]
  }
}

# ── SKE landing zones (dev + prod) ──

locals {
  landing_zones = {
    dev = {
      display_name = "SKE Kubernetes Namespace – Development"
      description  = "Landing zone for development workloads."
      quotas = [
        { key = "limits.cpu", value = 500 },
        { key = "requests.cpu", value = 250 },
        { key = "limits.memory", value = 512 },
        { key = "requests.memory", value = 256 },
        { key = "requests.storage", value = 1 },
        { key = "persistentvolumeclaims", value = 2 },
      ]
    }
    prod = {
      display_name = "SKE Kubernetes Namespace – Production"
      description  = "Landing zone for production workloads."
      quotas = [
        { key = "limits.cpu", value = 1000 },
        { key = "requests.cpu", value = 500 },
        { key = "limits.memory", value = 1024 },
        { key = "requests.memory", value = 512 },
        { key = "requests.storage", value = 2 },
        { key = "persistentvolumeclaims", value = 4 },
      ]
    }
  }
}

resource "meshstack_landingzone" "this" {
  for_each = local.landing_zones

  metadata = {
    name               = "${local.platform_identifier}-${each.key}"
    owned_by_workspace = var.workspace
    tags = merge(var.tags.landingzone, {
      "environment" = [each.key]
    })
  }

  spec = {
    display_name                  = each.value.display_name
    description                   = each.value.description
    automate_deletion_approval    = true
    automate_deletion_replication = true

    platform_ref = {
      uuid = meshstack_platform.ske.metadata.uuid
    }

    platform_properties = {
      kubernetes = {
        kubernetes_role_mappings = [
          {
            project_role_ref = { name = "admin" }
            platform_roles   = ["admin"]
          },
          {
            project_role_ref = { name = "user" }
            platform_roles   = ["edit"]
          },
          {
            project_role_ref = { name = "reader" }
            platform_roles   = ["view"]
          },
        ]
      }
    }

    quotas = each.value.quotas
  }
}
