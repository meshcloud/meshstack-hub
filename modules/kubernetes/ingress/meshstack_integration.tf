variable "cert_manager_version" {
  type        = string
  nullable    = false
  default     = "v1.20.0"
  description = "Version of the cert-manager Helm chart the definition installs."
}

variable "haproxy_version" {
  type        = string
  nullable    = false
  default     = "1.49.0"
  description = "Version of the haproxytech/kubernetes-ingress Helm chart the definition installs."
}

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

variable "ingress_class_name" {
  type        = string
  nullable    = false
  default     = "haproxy"
  description = "Name of the IngressClass the controller serves."
}

variable "cluster_issuer_name" {
  type        = string
  nullable    = false
  default     = "letsencrypt-prod"
  description = "Name of the ClusterIssuer application teams put in their cert-manager.io/cluster-issuer annotation."
}

variable "acme_server" {
  type        = string
  nullable    = false
  default     = "https://acme-v02.api.letsencrypt.org/directory"
  description = "ACME directory URL. Point this at the staging endpoint while testing — production has strict rate limits."
}

variable "acme_email" {
  type        = string
  nullable    = false
  default     = "platform@meshcloud.io"
  description = "Contact address Let's Encrypt uses for expiry warnings and account recovery."
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
    version_ref = meshstack_building_block_definition.this.version_latest
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name        = coalesce(var.bbd_display_name, "Kubernetes Ingress")
    symbol              = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/kubernetes/ingress/buildingblock/logo.png"
    description         = coalesce(var.bbd_description, "Installs cert-manager, the HAProxy ingress controller and a Let's Encrypt ClusterIssuer on a Kubernetes cluster.")
    support_url         = "https://cert-manager.io/docs/"
    target_type         = "TENANT_LEVEL"
    run_transparency    = true
    supported_platforms = [{ name = "STACKIT" }]

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
      Makes a Kubernetes cluster serve HTTPS: **cert-manager**, the **HAProxy ingress controller**
      behind a cloud LoadBalancer, and a Let's Encrypt **ClusterIssuer** application teams reference
      from their Ingress.

      ## 🎯 When to use it

      This is a bootstrap block a platform team orders once per cluster — for example the **STACKIT
      Kubernetes Platform** reference architecture orders it right after the cluster exists. It
      configures its `kubernetes` and `helm` providers from a kubeconfig input, so it runs in a
      separate apply from the cluster creation.

      ## 📦 Resources created

      - **cert-manager** – with its CRDs, sized for a demonstration cluster.
      - **HAProxy ingress controller** – exposed through a cloud LoadBalancer whose external IP is
        reported as an output, for the DNS A record.
      - **Let's Encrypt ClusterIssuer** – rendered through an inline Helm chart, so no separate run
        is needed to wait for the cert-manager CRDs.

      ## 🔗 How an application uses it

      Put `kubernetes.io/ingress.class: haproxy` and
      `cert-manager.io/cluster-issuer: letsencrypt-prod` on an Ingress and cert-manager issues a
      certificate for its hostname over HTTP-01.

      ## 📊 Shared responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Provide the cluster kubeconfig and the ACME contact address | ✅ | ❌ |
      | Install and maintain cert-manager and the ingress controller | ✅ | ❌ |
      | Point DNS at the reported LoadBalancer IP | ✅ | ❌ |
      | Create Ingress resources and reference the ClusterIssuer | ❌ | ✅ |
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
        repository_path                = "modules/kubernetes/ingress/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      kubeconfig = {
        display_name    = "Cluster Kubeconfig"
        description     = "Raw kubeconfig (YAML) of the cluster to install ingress on."
        type            = "CODE"
        assignment_type = "USER_INPUT"
        sensitive       = {}

        # A composing architecture hands this over from the cluster it created, and a rotated
        # kubeconfig has to reach the block that was already ordered with the old one.
        updateable_by_consumer = true
      }

      # STATIC, not USER_INPUT, and for a mechanical reason as much as a policy one: the meshstack
      # provider throws "inconsistent values for sensitive attribute" when one building block's
      # inputs map mixes a `sensitive` and a plain `value` input, and `kubeconfig` above is
      # sensitive. Keeping every other order-time input off the block avoids that, and the ACME
      # contact is a platform-team decision anyway.
      acme_email = {
        display_name    = "ACME Contact Email"
        description     = "Contact address Let's Encrypt uses for expiry warnings and account recovery."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.acme_email)
      }

      acme_server = {
        display_name    = "ACME Directory URL"
        description     = "ACME directory URL the ClusterIssuer registers against."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.acme_server)
      }

      cluster_issuer_name = {
        display_name    = "ClusterIssuer Name"
        description     = "Name application teams reference from the cert-manager.io/cluster-issuer annotation."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.cluster_issuer_name)
      }

      ingress_class_name = {
        display_name    = "Ingress Class Name"
        description     = "Name of the IngressClass the controller serves."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.ingress_class_name)
      }

      cert_manager_version = {
        display_name    = "cert-manager Chart Version"
        description     = "Version of the cert-manager Helm chart."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.cert_manager_version)
      }

      haproxy_version = {
        display_name    = "HAProxy Chart Version"
        description     = "Version of the haproxytech/kubernetes-ingress Helm chart."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.haproxy_version)
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
    }

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
