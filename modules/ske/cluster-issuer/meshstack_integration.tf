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

variable "cluster_issuer_email" {
  type        = string
  nullable    = false
  default     = "ske@meshcloud.io"
  description = "Contact email registered with Let's Encrypt for the ACME ClusterIssuer. Baked into the definition as a STATIC input."
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
    display_name        = coalesce(var.bbd_display_name, "STACKIT SKE Cluster Issuer")
    symbol              = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/ske/cluster-issuer/buildingblock/logo.png"
    description         = coalesce(var.bbd_description, "Installs a Let's Encrypt ClusterIssuer (cert-manager) on an SKE cluster for automatic TLS.")
    support_url         = "https://portal.stackit.cloud/ske"
    target_type         = "TENANT_LEVEL"
    run_transparency    = true
    supported_platforms = [{ name = "STACKIT" }]

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
      Installs a Let's Encrypt **ClusterIssuer** (cert-manager) on an existing **STACKIT Kubernetes
      Engine (SKE)** cluster, so ingress hosts get automatic TLS certificates.

      ## 🎯 When to use it

      This is a bootstrap block ordered by the **STACKIT Kubernetes Platform** reference architecture
      *after* the platform-services block has installed cert-manager. It is a separate building block on
      purpose: a `ClusterIssuer` can only be applied once the cert-manager CRDs exist on the cluster,
      which happens in the preceding platform-services run.

      ## 📦 Resources created

      - **ClusterIssuer `letsencrypt-prod`** – an ACME issuer using the Let's Encrypt production
        directory, solving HTTP-01 challenges through the ingress class.

      ## 📊 Shared responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Provide the cluster kubeconfig and issuer email | ✅ | ❌ |
      | Install and maintain the ClusterIssuer | ✅ | ❌ |
      | Request Certificates / annotate Ingresses for TLS | ❌ | ✅ |
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
        repository_path                = "modules/ske/cluster-issuer/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      # A composing architecture passes the cluster's kubeconfig output down as this input. It configures
      # the kubernetes provider, so it must be a concrete value (the cluster already exists, and
      # cert-manager is already installed, in preceding building blocks).
      kubeconfig = {
        display_name    = "Cluster Kubeconfig"
        description     = "Raw kubeconfig (YAML) of the SKE cluster to install the ClusterIssuer on."
        type            = "CODE"
        assignment_type = "USER_INPUT"
        sensitive       = {}
      }

      cluster_issuer_email = {
        display_name    = "ClusterIssuer Email"
        description     = "Contact email registered with Let's Encrypt for the ACME ClusterIssuer."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.cluster_issuer_email)
      }

      ingress_class_name = {
        display_name    = "Ingress Class Name"
        description     = "Ingress class the ACME HTTP-01 solver routes challenges through."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode("haproxy")
      }
    }

    outputs = {}

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
