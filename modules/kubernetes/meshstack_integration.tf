variable "replicator_token" {
  type        = string
  nullable    = false
  sensitive   = true
  description = "Replicator service account token, from an ordered instance of the building block definition this registers."
}

variable "metering_token" {
  type        = string
  nullable    = false
  sensitive   = true
  description = "Metering service account token, from the same building block instance as `replicator_token`."
}

variable "kube_host" {
  type        = string
  nullable    = false
  description = "API server URL of the cluster, used as the platform endpoint and replication base URL."
}

variable "disable_ssl_validation" {
  type        = bool
  nullable    = false
  default     = true
  description = "Skip TLS verification when meshStack talks to the cluster API."
}

variable "namespace_name_pattern" {
  type        = string
  nullable    = false
  default     = "#{workspaceIdentifier}-#{projectIdentifier}"
  description = "Pattern meshStack uses to name the namespace it replicates per tenant."
}

variable "quota_definitions" {
  type = list(object({
    quota_key               = string
    label                   = string
    description             = string
    unit                    = string
    min_value               = number
    max_value               = number
    auto_approval_threshold = number
  }))
  nullable    = false
  description = "Quotas the platform offers. CPU in millicores (m), memory in mebibytes (Mi), so values stay whole integers."

  default = [
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

variable "landing_zones" {
  type = map(object({
    display_name = optional(string)
    description  = optional(string)
    tags         = optional(map(list(string)), {})
    quotas = optional(list(object({
      key   = string
      value = number
    })))
  }))
  nullable    = false
  description = <<-EOT
  Landing zones created on the platform, keyed by stage. The key is the only required part, so a platform can offer any set of stages.
  `display_name` and `description` default to a name built from the key.
  `quotas` defaults to a built-in set, the larger one for `prod`.
  EOT

  default = {
    dev  = { tags = { environment = ["dev"] } }
    prod = { tags = { environment = ["prod"] } }
  }
}

variable "kubernetes_role_mappings" {
  type = list(object({
    project_role_ref = object({ name = string })
    platform_roles   = list(string)
  }))
  nullable    = false
  description = "Mapping from meshStack project roles to Kubernetes RBAC roles, applied to every landing zone."

  default = [
    { project_role_ref = { name = "admin" }, platform_roles = ["admin"] },
    { project_role_ref = { name = "user" }, platform_roles = ["edit"] },
    { project_role_ref = { name = "reader" }, platform_roles = ["view"] },
  ]
}

variable "service_account_namespace" {
  type        = string
  nullable    = false
  default     = "meshcloud"
  description = "Namespace that holds the replicator and metering service accounts."
}

variable "metering_enabled" {
  type        = bool
  nullable    = false
  default     = true
  description = "Create the metering service account. Turn this off when meshStack should not collect usage data from the cluster."
}

variable "replicator_additional_rules" {
  type = list(object({
    api_groups        = list(string)
    resources         = list(string)
    verbs             = list(string)
    resource_names    = optional(list(string))
    non_resource_urls = optional(list(string))
  }))
  nullable    = false
  default     = []
  description = "Extra RBAC rules added to the replicator cluster role."
}

variable "metering_additional_rules" {
  type = list(object({
    api_groups        = list(string)
    resources         = list(string)
    verbs             = list(string)
    resource_names    = optional(list(string))
    non_resource_urls = optional(list(string))
  }))
  nullable    = false
  default     = []
  description = "Extra RBAC rules added to the metering cluster role."
}

variable "bbd_display_name" {
  type        = string
  default     = null
  description = "Overrides the name of the marketplace entry application teams see in the catalog."
}

variable "bbd_description" {
  type        = string
  default     = null
  description = "Overrides the one-line description shown next to the marketplace entry."
}

variable "bbd_readme" {
  type        = string
  default     = null
  description = "Overrides the markdown readme shown in the marketplace before ordering."
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    tags = optional(object({
      landingzone    = map(list(string))
      building_block = map(list(string))
    }), { landingzone = {}, building_block = {} })
    location_name       = optional(string, "global")
    platform_identifier = optional(string, "kubernetes")
  })
  description = <<-EOT
  Shared meshStack context.
  `owning_workspace_identifier`: Identifier of the meshStack workspace that owns the managed resources.
  `tags`: Optional tags propagated to building block definition and landing zone metadata. A landing zone's own `tags` win over `landingzone`.
  `location_name`: meshStack location name for the platform. Defaults to "global".
  `platform_identifier`: Identifier for the platform in meshStack. Defaults to "kubernetes".
  EOT
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
  `git_ref`: Hub release reference. Set to a tag (e.g. 'v1.2.3') or branch or commit sha of meshcloud/meshstack-hub repo.
  `bbd_draft`: If true, allows changing the building block definition for upgrading dependent building blocks.
  EOT
}

output "building_block_definition" {
  description = "BBD is consumed in building block compositions."
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = meshstack_building_block_definition.this.version_latest
  }
}

output "platform_ref" {
  description = "Reference to the meshPlatform this integration creates, for compositions that create meshTenants on it."
  value       = meshstack_platform.this.ref
}

output "landingzone_refs" {
  description = "References to the created landing zones, keyed as in `landing_zones`."
  value       = { for key, lz in meshstack_landingzone.this : key => lz.ref }
}

locals {
  default_quotas = [
    { key = "limits.cpu", value = 500 },
    { key = "requests.cpu", value = 250 },
    { key = "limits.memory", value = 512 },
    { key = "requests.memory", value = 256 },
    { key = "requests.storage", value = 1 },
    { key = "persistentvolumeclaims", value = 2 },
  ]

  prod_quotas = [
    { key = "limits.cpu", value = 1000 },
    { key = "requests.cpu", value = 500 },
    { key = "limits.memory", value = 1024 },
    { key = "requests.memory", value = 512 },
    { key = "requests.storage", value = 2 },
    { key = "persistentvolumeclaims", value = 4 },
  ]

  landing_zones = {
    for key, lz in var.landing_zones : key => {
      display_name = coalesce(lz.display_name, "Kubernetes Namespace – Stage ${title(key)}")
      description  = coalesce(lz.description, "Landing zone for ${key} workloads.")
      tags         = lz.tags
      quotas       = coalesce(lz.quotas, key == "prod" ? local.prod_quotas : local.default_quotas)
    }
  }
}

resource "meshstack_platform" "this" {
  metadata = {
    name               = var.meshstack.platform_identifier
    owned_by_workspace = var.meshstack.owning_workspace_identifier
  }

  lifecycle {
    ignore_changes = [spec.availability]
  }

  spec = {
    display_name      = "Kubernetes namespace (${var.meshstack.platform_identifier})"
    description       = "Provides a Kubernetes namespace with role-based access control and quotas."
    endpoint          = var.kube_host
    documentation_url = "https://docs.meshcloud.io/docs/meshstack.kubernetes.index.html"
    support_url       = ""

    location_ref = {
      name = var.meshstack.location_name
    }

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
              secret_value   = var.replicator_token
              secret_version = nonsensitive(sha256(var.replicator_token))
            }
          }
          namespace_name_pattern = var.namespace_name_pattern
        }

        metering = {
          client_config = {
            access_token = {
              secret_value   = var.metering_token
              secret_version = nonsensitive(sha256(var.metering_token))
            }
          }
          processing = {
            compact_timelines_after_days = 30
            delete_raw_data_after_days   = 65
          }
        }
      }
    }

    quota_definitions = var.quota_definitions
  }
}

resource "meshstack_landingzone" "this" {
  for_each = local.landing_zones

  metadata = {
    name               = "${var.meshstack.platform_identifier}-namespace-${each.key}"
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = merge(var.meshstack.tags.landingzone, each.value.tags)
  }

  spec = {
    display_name                  = each.value.display_name
    description                   = each.value.description
    automate_deletion_approval    = true
    automate_deletion_replication = true

    platform_ref = meshstack_platform.this.ref

    platform_properties = {
      kubernetes = {
        kubernetes_role_mappings = var.kubernetes_role_mappings
      }
    }

    quotas = each.value.quotas
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags.building_block
  }

  spec = {
    display_name        = coalesce(var.bbd_display_name, "Kubernetes meshPlatform Credentials")
    symbol              = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/kubernetes/platform/logo.png"
    description         = coalesce(var.bbd_description, "Creates the in-cluster replicator and metering service accounts meshStack authenticates with, and returns their tokens.")
    support_url         = "https://docs.meshcloud.io/docs/meshstack.kubernetes.index.html"
    target_type         = "TENANT_LEVEL"
    run_transparency    = true
    supported_platforms = [{ name = "STACKIT" }]

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
      Creates the two in-cluster identities meshStack uses to drive a Kubernetes cluster, and hands
      their tokens back to the composition that ordered it.

      ## 🎯 When to use it

      A platform team orders this once per cluster, as part of turning that cluster into a meshStack
      platform — the **STACKIT Kubernetes Platform** reference architecture does it right after the
      cluster exists and feeds the tokens into the platform it registers. It configures its
      `kubernetes` provider from a kubeconfig input, so it runs in a separate apply from the cluster
      creation.

      ## 📦 Resources created

      - **Replicator identity** (`meshfed-service`) – ServiceAccount, token Secret, ClusterRole and
        ClusterRoleBinding allowing meshStack to create namespaces, resource quotas and role
        bindings for every tenant.
      - **Metering identity** (`meshfed-metering`) – the same four objects, allowed only to read
        pods and persistent volume claims. Optional.

      ## ℹ️ It does not register a platform

      Deciding that a cluster becomes a meshStack platform — identifier, location, landing zones,
      quotas — belongs to the composition that owns the cluster. This block only produces the
      credentials that registration needs.

      ## 📊 Shared responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Provide the cluster kubeconfig | ✅ | ❌ |
      | Maintain the replicator and metering identities and their permissions | ✅ | ❌ |
      | Consume namespaces meshStack replicates onto the cluster | ❌ | ✅ |
      EOT
    ))
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"

    implementation = {
      terraform = {
        terraform_version              = "1.12.5"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/kubernetes/platform"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      kubeconfig = {
        display_name    = "Cluster Kubeconfig"
        description     = "Raw kubeconfig (YAML) of the cluster to create the meshStack identities in."
        type            = "CODE"
        assignment_type = "USER_INPUT"
        sensitive       = {}

        # A composing architecture hands this over from the cluster it created, and a rotated
        # kubeconfig has to reach the block that was already ordered with the old one.
        updateable_by_consumer = true
      }

      service_account_namespace = {
        display_name    = "Service Account Namespace"
        description     = "Namespace that holds the replicator and metering service accounts."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.service_account_namespace)
      }

      metering_enabled = {
        display_name    = "Metering Enabled"
        description     = "Create the metering service account so meshStack can collect usage data."
        type            = "BOOLEAN"
        assignment_type = "STATIC"
        argument        = jsonencode(var.metering_enabled)
      }

      replicator_additional_rules = {
        display_name    = "Replicator Additional Rules"
        description     = "Extra RBAC rules added to the replicator cluster role."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.replicator_additional_rules))
      }

      metering_additional_rules = {
        display_name    = "Metering Additional Rules"
        description     = "Extra RBAC rules added to the metering cluster role."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.metering_additional_rules))
      }
    }

    outputs = {
      # Consumed by the composing architecture (read from this block's status outputs) to wire up
      # the meshstack_platform. Sensitive service account tokens — do not publish this definition
      # outside the platform workspace.
      replicator_token = {
        display_name    = "Replicator Token"
        type            = "STRING"
        assignment_type = "NONE"
      }

      metering_token = {
        display_name    = "Metering Token"
        type            = "STRING"
        assignment_type = "NONE"
      }

      service_account_namespace = {
        display_name    = "Service Account Namespace"
        type            = "STRING"
        assignment_type = "NONE"
      }
    }

    permissions = []
  }
}

terraform {
  required_version = ">= 1.12.0"

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.24.0"
    }
  }
}
