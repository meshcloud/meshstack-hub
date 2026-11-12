variable "haproxy_replica_count" {
  type        = number
  nullable    = false
  default     = 1
  description = "Number of HAProxy ingress controller replicas. 1 is a demonstration default and gives no redundancy; production wants at least 2."
}

variable "haproxy_service_annotations" {
  type        = map(string)
  nullable    = false
  default     = {}
  description = "Annotations on the HAProxy controller Service, read by the cloud provider to configure the load balancer."
}

variable "use_letsencrypt_staging" {
  type        = bool
  nullable    = false
  default     = false
  description = "Issue from Let's Encrypt staging, for development and testing: its rate limits are far higher, but no browser trusts its certificates."
}

variable "acme_email" {
  type        = string
  nullable    = false
  description = "Contact address Let's Encrypt uses for expiry warnings and account recovery."
}

variable "wildcard_certs" {
  type = object({
    domain       = string
    dns01_solver = any
  })
  default     = null
  description = "If set to null, cert-manager issues an individual certificate per Ingress over HTTP-01. If set, cert-manager issues `*.<domain>` over DNS-01 with `dns01_solver`, the `dns01` block of a cert-manager ACME solver such as the one `stackit/dns` shows, and HAProxy serves it to every Ingress."
}

variable "cluster_definition_ref" {
  type = object({
    kind = string
    uuid = string
  })
  default     = null
  description = "Ref of the cluster definition (for example `ske/cluster`) whose building blocks parent this definition's building blocks; null declares no dependency."
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

variable "approval_policies" {
  type = object({
    building_block_creation = optional(bool, false)
    user_input_changes      = optional(bool, false)
    any_input_changes       = optional(bool, false)
    manual_triggers         = optional(bool, false)
    version_upgrade         = optional(bool, false)
  })
  nullable    = false
  default     = {}
  description = "Run triggers that need an operator's approval on this definition."
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    tags                        = optional(map(list(string)), {})
    runner_ref = optional(object({
      kind = string
      uuid = string
    }))
    supported_platforms = list(object({
      kind = optional(string)
      name = optional(string)
      uuid = optional(string)
    }))
  })
  description = "Shared meshStack context, see docs."
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
  `bbd_draft`: If true, the building block definition version is kept in draft mode.
  EOT
}

output "building_block_definition" {
  description = "BBD is consumed in building block compositions."
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = meshstack_building_block_definition.this.version_latest
  }
}

locals {
  cluster_issuer_name = var.use_letsencrypt_staging ? "letsencrypt-staging" : "letsencrypt-prod"

  app_usage = var.wildcard_certs == null ? chomp(<<-EOT
    Set `ingressClassName: haproxy` and the annotation
    `cert-manager.io/cluster-issuer: ${local.cluster_issuer_name}` on an Ingress, and cert-manager
    issues a certificate for its hostname over HTTP-01.
    EOT
    ) : chomp(<<-EOT
    Set `ingressClassName: haproxy` and list the hostname under `tls`. HAProxy serves
    `*.${var.wildcard_certs.domain}` for it.
    EOT
  )
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name              = coalesce(var.bbd_display_name, "Kubernetes Ingress Controller")
    symbol                    = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/kubernetes/ingress-controller/buildingblock/logo.png"
    description               = coalesce(var.bbd_description, "Installs cert-manager, the HAProxy ingress controller and a Let's Encrypt ClusterIssuer on a Kubernetes cluster.")
    support_url               = "https://cert-manager.io/docs/"
    target_type               = "TENANT_LEVEL"
    run_transparency          = true
    approval_policies         = var.approval_policies
    supported_platforms       = var.meshstack.supported_platforms
    use_in_landing_zones_only = true

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
      Makes a Kubernetes cluster serve HTTPS: **cert-manager**, the **HAProxy ingress controller**
      behind a cloud LoadBalancer, and a Let's Encrypt **ClusterIssuer** application teams reference
      from their Ingress.

      ## 🎯 When to use it

      This block is meant for landing zones and compositions, which add it once per cluster, such as
      the **STACKIT Kubernetes Platform** reference architecture, which passes the cluster's
      kubeconfig. Application teams deploy their `Ingress`
      with the **Kubernetes Manifest** building block.

      ## 📦 Resources created

      - **cert-manager** – with its CRDs, sized for a demonstration cluster.
      - **HAProxy ingress controller** – exposed through a cloud LoadBalancer whose external IP is
        reported as an output, for the DNS A record.
      - **Let's Encrypt ClusterIssuer** – rendered through an inline Helm chart, so no separate run
        is needed to wait for the cert-manager CRDs.

      ## 🔗 How an application uses it

      ${local.app_usage}

      ## 📊 Shared responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Provide the cluster kubeconfig and the ACME contact address | ✅ | ❌ |
      | Install and maintain cert-manager and the ingress controller | ✅ | ❌ |
      | Point DNS at the reported LoadBalancer IP | ✅ | ❌ |
      | Create Ingress resources for their hostnames | ❌ | ✅ |
      EOT
    ))
  }

  version_spec = {
    draft           = var.hub.bbd_draft
    runner_ref      = var.meshstack.runner_ref
    deletion_mode   = "DELETE"
    dependency_refs = var.cluster_definition_ref == null ? null : [var.cluster_definition_ref]

    implementation = {
      terraform = {
        terraform_version              = "1.12.5"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/kubernetes/ingress-controller/buildingblock"
        ref_name                       = var.hub.git_ref
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = merge({
      "kubeconfig.yaml" = {
        display_name           = "kubeconfig.yaml"
        description            = "Kubeconfig of the cluster to install the ingress controller on."
        type                   = "FILE"
        assignment_type        = "USER_INPUT"
        sensitive              = {}
        updateable_by_consumer = true
      }

      acme_email = {
        display_name    = "ACME Contact Email"
        description     = "Contact address Let's Encrypt uses for expiry warnings and account recovery."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.acme_email)
      }

      use_letsencrypt_staging = {
        display_name    = "Use Let's Encrypt Staging"
        description     = "Issue from Let's Encrypt staging, for development and testing. No browser trusts its certificates."
        type            = "BOOLEAN"
        assignment_type = "STATIC"
        argument        = jsonencode(var.use_letsencrypt_staging)
      }

      haproxy_replica_count = {
        display_name    = "HAProxy Replicas"
        description     = "Number of HAProxy ingress controller replicas."
        type            = "INTEGER"
        assignment_type = "STATIC"
        argument        = jsonencode(var.haproxy_replica_count)
      }

      haproxy_service_annotations = {
        display_name    = "HAProxy Service Annotations"
        description     = "Annotations on the controller Service, read by the cloud provider to configure the load balancer."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.haproxy_service_annotations))
      }

      imports = {
        display_name    = "Imports"
        description     = "HCL `{}` takes over the existing namespaces, Helm releases and ClusterIssuer; empty installs anew."
        type            = "CODE"
        assignment_type = "USER_INPUT"
        is_optional     = true
      }

      release_on_destroy = {
        display_name           = "Release on Destroy"
        description            = "Leave the namespaces and Helm releases in place when this building block is deleted. Cannot change once they are managed."
        type                   = "BOOLEAN"
        assignment_type        = "USER_INPUT"
        default_value          = jsonencode(false)
        updateable_by_consumer = true
      }
      }, var.wildcard_certs == null ? {} : {
      wildcard_certs = {
        display_name    = "Wildcard Certificates"
        description     = "Domain of the wildcard certificate and the cert-manager DNS-01 solver that issues it."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.wildcard_certs))
      }
    })

    outputs = {
      haproxy_lb_ip = {
        display_name    = "HAProxy LoadBalancer IP"
        type            = "STRING"
        assignment_type = "NONE"
      }

      ingress_class_name = {
        display_name    = "Ingress Class Name"
        type            = "STRING"
        assignment_type = "NONE"
      }

      cluster_issuer_name = {
        display_name    = "ClusterIssuer Name"
        type            = "STRING"
        assignment_type = "NONE"
      }

      summary = {
        display_name    = "Summary"
        type            = "STRING"
        assignment_type = "SUMMARY"
      }
    }

    permissions = []
  }
}

terraform {
  required_version = ">= 1.12.0"

  required_providers {
    meshstack = {
      source = "meshcloud/meshstack"
      # 0.25.2 is the first release that accepts `spec.approval_policies`.
      version = ">= 0.25.2"
    }
  }
}
