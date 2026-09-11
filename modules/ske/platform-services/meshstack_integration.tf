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
    display_name     = coalesce(var.bbd_display_name, "STACKIT SKE Platform Services")
    symbol           = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/ske/platform-services/buildingblock/logo.png"
    description      = coalesce(var.bbd_description, "Installs HAProxy ingress, cert-manager and the meshStack replication/metering service accounts on an SKE cluster.")
    support_url      = "https://portal.stackit.cloud/ske"
    target_type      = "WORKSPACE_LEVEL"
    run_transparency = true

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
      Installs the in-cluster services that turn an existing **STACKIT Kubernetes Engine (SKE)**
      cluster into a meshStack platform: HAProxy ingress behind a STACKIT LoadBalancer, cert-manager
      with a Let's Encrypt `ClusterIssuer`, and the meshStack replication and metering service
      accounts.

      ## 🎯 When to use it

      This is a bootstrap block ordered by the **STACKIT Kubernetes Platform** reference architecture
      after it creates the SKE cluster. It configures its `kubernetes`/`helm` providers from a
      kubeconfig input, so it runs in a separate apply from the cluster creation.

      ## 📦 Resources created

      - **HAProxy ingress** – exposes an external LoadBalancer IP for application DNS.
      - **cert-manager + Let's Encrypt ClusterIssuer** – automatic TLS for ingress hosts.
      - **meshStack replication/metering service accounts** – their tokens are handed back to the
        composing architecture to wire up the meshStack platform.

      ## 📊 Shared responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Provide the cluster kubeconfig and issuer email | ✅ | ❌ |
      | Install and maintain ingress, cert-manager and the replication service accounts | ✅ | ❌ |
      | Deploy application workloads and Ingress resources | ❌ | ✅ |
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
        repository_path                = "modules/ske/platform-services/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      # A composing architecture passes the cluster's kubeconfig output down as this input. It
      # configures the kubernetes/helm providers, so it must be a concrete value (the cluster already
      # exists in a preceding building block).
      kubeconfig = {
        display_name    = "Cluster Kubeconfig"
        description     = "Raw kubeconfig (YAML) of the SKE cluster to install platform services on."
        type            = "CODE"
        assignment_type = "USER_INPUT"
        sensitive       = {}
      }

      cluster_issuer_email = {
        display_name    = "ClusterIssuer Email"
        description     = "Contact email registered with Let's Encrypt for the ACME ClusterIssuer."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode("ske@meshcloud.io")
      }

      cert_manager_version = {
        display_name    = "cert-manager Chart Version"
        description     = "cert-manager Helm chart version."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode("v1.20.0")
      }

      haproxy_version = {
        display_name    = "HAProxy Chart Version"
        description     = "HAProxy Kubernetes Ingress Helm chart version."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode("1.49.0")
      }

      haproxy_replica_count = {
        display_name    = "HAProxy Replicas"
        description     = "Number of HAProxy ingress controller replicas."
        type            = "INTEGER"
        assignment_type = "STATIC"
        argument        = jsonencode(2)
      }
    }

    outputs = {
      haproxy_lb_ip = {
        display_name    = "HAProxy LoadBalancer IP"
        type            = "STRING"
        assignment_type = "NONE"
      }

      # Consumed by the composing architecture (read from this block's status outputs) to wire up the
      # meshstack_platform. Sensitive service account tokens — do not publish outside the platform workspace.
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
