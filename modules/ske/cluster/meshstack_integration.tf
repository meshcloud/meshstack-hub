variable "external_service_account" {
  type        = bool
  nullable    = false
  default     = false
  description = <<-EOT
  When true, the cluster does not create its own backplane service account. Instead the composing
  architecture supplies the automation identity as the order-time `STACKIT_SERVICE_ACCOUNT_EMAIL`
  input — e.g. a service account minted by the STACKIT Service Account building block that already
  holds SKE permissions on the target project and trusts this definition's WIF subject. Default
  false keeps the standalone behaviour: the module's own backplane creates and pins the identity.
  EOT

  validation {
    condition     = var.external_service_account || (var.stackit_backplane_project_id != null && var.stackit_backplane_folder_id != null)
    error_message = "stackit_backplane_project_id and stackit_backplane_folder_id are required unless external_service_account is true."
  }
}

variable "stackit_backplane_project_id" {
  type        = string
  nullable    = true
  default     = null
  description = "Existing STACKIT project the backplane creates the automation service account in (e.g. a foundation project). Not the cluster's own project, which is provisioned at order time and supplied as the buildingblock's `stackit_project_id` input. Unused (leave null) when external_service_account is true."
}

variable "stackit_backplane_folder_id" {
  type        = string
  nullable    = true
  default     = null
  description = "STACKIT resource-manager folder the automation service account is granted SKE roles on, so the grant is inherited by the cluster project created at order time inside that folder. This is the folder's `folder_id`. Unused (leave null) when external_service_account is true."
}

variable "roles" {
  type        = list(string)
  nullable    = false
  default     = ["ske.admin"]
  description = <<-EOT
  Roles granted to the backplane service account on the folder, inherited by the project the cluster is
  created in. Assigned at folder scope, where STACKIT service roles like `ske.admin` are valid (they are
  rejected at organization scope). Unused when external_service_account is true.
  EOT
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

data "meshstack_integrations" "integrations" {}

module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/ske/cluster/backplane?ref=${var.hub.git_ref}"

  # Skipped in external-service-account mode: the composing architecture provides the identity instead.
  # The module stays instantiated (no module-level count) to preserve the BBD/backplane reference
  # structure OpenTofu resolves today; it just creates no service account or role grants when disabled.
  enabled = !var.external_service_account

  project_id = var.stackit_backplane_project_id
  folder_id  = var.stackit_backplane_folder_id
  roles      = var.roles

  workload_identity_federation = {
    issuer = data.meshstack_integrations.integrations.workload_identity_federation.replicator.issuer
    subjects = [
      "${trimsuffix(data.meshstack_integrations.integrations.workload_identity_federation.replicator.subject, ":replicator")}:workspace.${var.meshstack.owning_workspace_identifier}.buildingblockdefinition.${meshstack_building_block_definition.this.metadata.uuid}"
    ]
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name        = coalesce(var.bbd_display_name, "STACKIT SKE Cluster")
    symbol              = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/ske/cluster/buildingblock/logo.png"
    description         = coalesce(var.bbd_description, "Provisions a STACKIT Kubernetes Engine (SKE) cluster with a node pool and mints an admin kubeconfig.")
    support_url         = "https://portal.stackit.cloud/ske"
    target_type         = "TENANT_LEVEL"
    run_transparency    = true
    supported_platforms = [{ name = "STACKIT" }]

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
      # ── STACKIT authentication (Workload Identity Federation, no key) ──
      # In external-service-account mode the composing architecture supplies the identity as an
      # order-time USER_INPUT; otherwise it is STATIC from the module's own backplane. `argument` is
      # null (i.e. unset) for USER_INPUT.
      STACKIT_SERVICE_ACCOUNT_EMAIL = {
        display_name    = "STACKIT Service Account Email"
        description     = "Email of the STACKIT service account the provider authenticates as via WIF."
        type            = "STRING"
        assignment_type = var.external_service_account ? "USER_INPUT" : "STATIC"
        is_environment  = true
        argument        = var.external_service_account ? null : jsonencode(module.backplane.service_account_email)
      }

      STACKIT_USE_OIDC = {
        display_name    = "STACKIT Use OIDC"
        description     = "Enables OIDC-based WIF for the STACKIT provider."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode("1")
      }

      STACKIT_FEDERATED_TOKEN_FILE = {
        display_name    = "STACKIT Federated Token File"
        description     = "Path to the WIF token file injected by meshStack."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode("/var/run/secrets/workload-identity/azure/token")
      }

      # ── Cluster placement and identity ──
      stackit_project_id = {
        display_name    = "STACKIT Project ID"
        description     = "STACKIT project the SKE cluster is created in — the platform-native tenant id of the tenant this building block is added to."
        type            = "STRING"
        assignment_type = "PLATFORM_TENANT_ID"
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

      # Must be a currently-available STACKIT SKE minor (they retire old ones — 1.31 is already gone).
      # Maintenance patches it upward automatically; bump this when STACKIT drops the pinned minor.
      kubernetes_version_min = {
        display_name    = "Minimum Kubernetes Version"
        description     = "Minimum Kubernetes minor version to run. Empty lets STACKIT pick the current default."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode("1.34")
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
