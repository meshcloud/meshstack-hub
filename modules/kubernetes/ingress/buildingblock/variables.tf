# Every variable below `kubeconfig` is a pass-through to `./ingress`, where the reasoning behind
# each default lives. The defaults are repeated here rather than left to the submodule, because a
# wrapper that passes `null` would override the submodule's own default with it.

variable "kubeconfig" {
  type        = string
  sensitive   = true
  description = "Raw kubeconfig (YAML) of the cluster this runs against — for example the `kubeconfig` output of the STACKIT SKE Cluster building block. The kubernetes and helm providers are configured from it, so it must be a concrete value at plan time (i.e. supplied by a preceding building block, not created in this run)."
}

# ── cert-manager ──

variable "cert_manager_version" {
  type        = string
  default     = "v1.20.0"
  description = "Version of the cert-manager Helm chart. See https://github.com/cert-manager/cert-manager/releases."
}

variable "cert_manager_namespace" {
  type        = string
  default     = "cert-manager"
  description = "Namespace for cert-manager and, when DNS-01 runs through STACKIT, for the STACKIT cert-manager webhook."
}

variable "cert_manager_extra_args" {
  type        = list(string)
  default     = ["--certificate-request-minimum-backoff-duration=1m"]
  description = "Extra command line arguments for the cert-manager controller. The default cuts the retry backoff for failed certificate requests from 1h to 1m."
}

variable "cert_manager_crds_keep" {
  type        = bool
  default     = false
  description = "Keep the cert-manager CRDs when the Helm release is destroyed."
}

variable "cert_manager_resources" {
  type = object({
    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})
    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})
  })
  nullable = false
  default = {
    requests = { cpu = "10m", memory = "64Mi" }
    limits   = { cpu = "200m", memory = "256Mi" }
  }
  description = "Resource requests and limits of the cert-manager controller. Sized for a demonstration cluster; see `ingress/variables.tf` for what production wants."
}

variable "cert_manager_webhook_resources" {
  type = object({
    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})
    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})
  })
  nullable = false
  default = {
    requests = { cpu = "10m", memory = "32Mi" }
    limits   = { cpu = "100m", memory = "128Mi" }
  }
  description = "Resource requests and limits of the cert-manager admission webhook. Sized for a demonstration cluster."
}

variable "cert_manager_cainjector_resources" {
  type = object({
    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})
    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})
  })
  nullable = false
  default = {
    requests = { cpu = "10m", memory = "64Mi" }
    limits   = { cpu = "200m", memory = "256Mi" }
  }
  description = "Resource requests and limits of the cert-manager cainjector. Sized for a demonstration cluster; its memory grows with the number of Secrets in the cluster."
}

variable "cert_manager_startupapicheck_resources" {
  type = object({
    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})
    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})
  })
  nullable = false
  default = {
    requests = { cpu = "10m", memory = "32Mi" }
    limits   = { cpu = "100m", memory = "128Mi" }
  }
  description = "Resource requests and limits of the cert-manager startupapicheck Job, which runs once per install and exits."
}

# ── HAProxy ingress controller ──

variable "haproxy_version" {
  type        = string
  default     = "1.49.0"
  description = "Version of the haproxytech/kubernetes-ingress Helm chart."
}

variable "haproxy_namespace" {
  type        = string
  default     = "haproxy-ingress"
  description = "Namespace for the HAProxy ingress controller. The wildcard certificate is created here too, so its secret survives the teardown of any application namespace."
}

variable "haproxy_release_name" {
  type        = string
  default     = "haproxy"
  description = "Helm release name of the HAProxy ingress controller. The chart names the controller Service '<release>-kubernetes-ingress'."
}

variable "haproxy_replica_count" {
  type        = number
  default     = 1
  description = "Number of HAProxy ingress controller replicas. The default of 1 gives no redundancy: every restart or node drain interrupts ingress traffic. Production wants at least 2."
}

variable "haproxy_resources" {
  type = object({
    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})
    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})
  })
  nullable = false
  default = {
    requests = { cpu = "100m", memory = "256Mi" }
    limits   = { cpu = "500m", memory = "768Mi" }
  }
  description = "Resource requests and limits of the HAProxy ingress controller. The memory limit must stay above ~500Mi or HAProxy reloads in a loop; see `ingress/variables.tf`."
}

variable "haproxy_crdjob_resources" {
  type = object({
    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})
    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})
  })
  nullable = false
  default = {
    requests = { cpu = "50m", memory = "64Mi" }
    limits   = { cpu = "200m", memory = "256Mi" }
  }
  description = "Resource requests and limits of the Job the HAProxy chart runs to install its CRDs."
}

variable "haproxy_service_type" {
  type        = string
  default     = "LoadBalancer"
  description = "Service type of the HAProxy ingress controller. The chart's own default is NodePort, which gives no public address at all."
}

variable "haproxy_service_annotations" {
  type        = map(string)
  default     = {}
  description = "Annotations on the HAProxy controller Service. The cloud provider reads them to configure the load balancer — e.g. `lb.stackit.cloud/internal-lb` on STACKIT."
}

variable "haproxy_timeout" {
  type        = number
  default     = 1200
  description = "Seconds to wait for the HAProxy Helm release to become ready. The default of 20 minutes covers the time a cloud provider takes to provision the load balancer."
}

variable "ingress_class_name" {
  type        = string
  default     = "haproxy"
  description = "Name of the IngressClass the controller serves. The HTTP-01 solver of the ClusterIssuer uses the same name."
}

# ── ACME / ClusterIssuer ──

variable "acme_email" {
  type        = string
  description = "Contact address Let's Encrypt uses for expiry warnings and account recovery."
}

variable "acme_server" {
  type        = string
  default     = "https://acme-v02.api.letsencrypt.org/directory"
  description = "ACME directory URL. Point this at the staging endpoint while testing, because production has strict rate limits."
}

variable "cluster_issuer_name" {
  type        = string
  default     = "letsencrypt-prod"
  description = "Name of the ClusterIssuer. Application teams reference it from the cert-manager.io/cluster-issuer annotation on their Ingress."
}

variable "acme_private_key_secret_name" {
  type        = string
  default     = "letsencrypt-prod-account-key"
  description = "Name of the secret in which cert-manager stores the ACME account private key."
}

# ── Optional DNS-01 wildcard certificate ──

variable "wildcard_certificate_name" {
  type        = string
  default     = "wildcard-tls"
  description = "Name of the wildcard Certificate and of the secret it writes, both in haproxy_namespace. Only used when dns01 is set."
}

variable "stackit_webhook_version" {
  type        = string
  default     = "0.4.9"
  description = "Version of the stackit-cert-manager-webhook Helm chart. Must be a version served by the chart index, which lags behind the GitHub release tags. Only used when dns01.stackit is set."
}

variable "stackit_webhook_resources" {
  type = object({
    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})
    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})
  })
  nullable = false
  default = {
    requests = { cpu = "10m", memory = "64Mi" }
    limits   = { cpu = "100m", memory = "128Mi" }
  }
  description = "Resource requests and limits of the STACKIT cert-manager webhook. Only used when dns01.stackit is set."
}

variable "dns01" {
  type = object({
    zone_name          = string
    certificate_domain = optional(string)
    stackit            = optional(object({ project_id = string, service_account_key = string }))
    route53            = optional(object({ hosted_zone_id = string, access_key_id = string, secret_access_key = string, region = optional(string, "eu-central-1") }))
  })
  default   = null
  sensitive = true

  description = <<-EOT
  Enables a wildcard certificate via DNS-01. Set exactly one provider. Null keeps HTTP-01
  per-hostname issuance, which needs no DNS credential and is what the STACKIT Kubernetes Platform
  reference architecture uses today. The submodule validates the object; see `ingress/variables.tf`.
  EOT
}
