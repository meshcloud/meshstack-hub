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
    display_name     = coalesce(var.bbd_display_name, "STACKIT SKE Cluster")
    symbol           = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/ske/cluster/buildingblock/logo.png"
    description      = coalesce(var.bbd_description, "Provisions a STACKIT Kubernetes Engine (SKE) cluster with a node pool and mints an admin kubeconfig.")
    support_url      = "https://portal.stackit.cloud/ske"
    target_type      = "WORKSPACE_LEVEL"
    run_transparency = true

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
      Provisions a **STACKIT Kubernetes Engine (SKE)** cluster with a single node pool and a nightly
      maintenance window, and mints an admin kubeconfig for it.

      ## 🎯 When to use it

      Use this building block when a platform team needs a managed Kubernetes cluster on STACKIT that
      a composing architecture can build on — for example the **STACKIT Kubernetes Platform**
      reference architecture, which orders this cluster first and then installs ingress, cert-manager
      and the meshStack SKE platform on top of it.

      ## 📦 Resources created

      - **SKE cluster** – a managed Kubernetes cluster in the given STACKIT project, with one node
        pool (default: `g2i.2`, 1-3 nodes) and automatic Kubernetes/machine-image updates.
      - **Admin kubeconfig** – a 180-day kubeconfig, auto-refreshed on apply, exposed as an output so
        a composing architecture can wire up its `kubernetes`/`helm` providers and downstream blocks.

      ## 🔑 Authentication

      Authenticates to STACKIT with a service account key (JSON), supplied as the
      `STACKIT_SERVICE_ACCOUNT_KEY` input. The account needs permission to manage SKE in the target
      project.

      ## 📊 Shared responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Provide the STACKIT project, service account key and cluster sizing | ✅ | ❌ |
      | Provision and maintain the SKE cluster | ✅ | ❌ |
      | Deploy workloads into the cluster's namespaces | ❌ | ✅ |
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
        repository_path                = "modules/ske/cluster/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      # ── STACKIT authentication ──
      # A composing architecture passes its own service account key down when it orders this cluster.
      STACKIT_SERVICE_ACCOUNT_KEY = {
        display_name    = "STACKIT Service Account Key"
        description     = "Service account key JSON used to authenticate the STACKIT provider. Needs permission to manage SKE in the target project."
        type            = "CODE"
        assignment_type = "USER_INPUT"
        is_environment  = true
        sensitive       = {}
      }

      # ── Cluster placement and identity ──
      stackit_project_id = {
        display_name                   = "STACKIT Project ID"
        description                    = "STACKIT project UUID the SKE cluster is created in."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
        validation_regex_error_message = "STACKIT Project ID must be a valid UUID."
      }

      cluster_name = {
        display_name                   = "Cluster Name"
        description                    = "Name of the SKE cluster (2-11 chars, lowercase alphanumeric or dashes, no leading/trailing dash)."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[a-z0-9][a-z0-9-]{0,9}[a-z0-9]$"
        validation_regex_error_message = "Cluster name must be 2-11 characters, lowercase alphanumeric or dashes, and not start or end with a dash."
      }

      # ── Cluster sizing (fixed by the definition; sensible STACKIT eu01 defaults) ──
      stackit_region = {
        display_name    = "STACKIT Region"
        description     = "STACKIT region the cluster and its node pool are placed in."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode("eu01")
      }

      kubernetes_version_min = {
        display_name    = "Minimum Kubernetes Version"
        description     = "Minimum Kubernetes minor version to run. Empty lets STACKIT pick the current default."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode("1.31")
      }

      node_pool = {
        display_name    = "Node Pool"
        description     = "HCL object describing the single node pool the cluster starts with."
        type            = "CODE"
        assignment_type = "STATIC"
        argument = jsonencode(jsonencode({
          name               = "pool-1"
          machine_type       = "g2i.2"
          minimum            = 1
          maximum            = 3
          availability_zones = ["eu01-1"]
          max_surge          = 1
        }))
      }

      maintenance = {
        display_name    = "Maintenance Window"
        description     = "HCL object describing the SKE maintenance window."
        type            = "CODE"
        assignment_type = "STATIC"
        argument = jsonencode(jsonencode({
          enable_kubernetes_version_updates    = true
          enable_machine_image_version_updates = true
          start                                = "01:00:00Z"
          end                                  = "02:00:00Z"
        }))
      }
    }

    outputs = {
      cluster_name = {
        display_name    = "Cluster Name"
        type            = "STRING"
        assignment_type = "NONE"
      }

      kube_host = {
        display_name    = "Kubernetes API Server"
        type            = "STRING"
        assignment_type = "NONE"
      }

      # Consumed by a composing architecture (read from this block's status outputs) to configure its
      # kubernetes/helm providers and hand cluster access to downstream building blocks. It carries
      # cluster-admin credentials — do not publish this definition outside the platform workspace.
      kubeconfig = {
        display_name    = "Kubeconfig"
        type            = "STRING"
        assignment_type = "NONE"
      }

      cluster_url = {
        display_name    = "Open Cluster"
        type            = "STRING"
        assignment_type = "RESOURCE_URL"
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
