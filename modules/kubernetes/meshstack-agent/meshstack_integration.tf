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
    tags                        = optional(map(list(string)), {})
  })
  description = "Shared meshStack context. Tags are optional and propagated to building block definition metadata."
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
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name        = coalesce(var.bbd_display_name, "meshStack Agent Identities")
    symbol              = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/kubernetes/meshstack-agent/buildingblock/logo.png"
    description         = coalesce(var.bbd_description, "Creates the in-cluster replicator and metering service accounts meshStack authenticates with, and returns their tokens.")
    support_url         = "https://docs.meshcloud.io/docs/meshstack.kubernetes.index.html"
    target_type         = "WORKSPACE_LEVEL"
    run_transparency    = true
    supported_platforms = [{ name = "KUBERNETES" }]

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
        repository_path                = "modules/kubernetes/meshstack-agent/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      # A composing architecture passes the cluster's kubeconfig output down as this input. It
      # configures the kubernetes provider, so it must be a concrete value (the cluster already
      # exists in a preceding building block).
      kubeconfig = {
        display_name    = "Cluster Kubeconfig"
        description     = "Raw kubeconfig (YAML) of the cluster to create the meshStack identities in."
        type            = "CODE"
        assignment_type = "USER_INPUT"
        sensitive       = {}
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
