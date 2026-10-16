variable "cert_manager_version" {
  type        = string
  nullable    = false
  description = "Version of the cert-manager Helm chart."
}

variable "cert_manager_namespace" {
  type        = string
  default     = "cert-manager"
  description = "Namespace of cert-manager and of the STACKIT cert-manager webhook."
}

variable "cert_manager_extra_args" {
  type = list(string)
  # The default backoff of 1h stalls an ACME order long after a transient DNS or ingress failure.
  default     = ["--certificate-request-minimum-backoff-duration=1m"]
  description = "Extra command line arguments for the cert-manager controller."
}

variable "cert_manager_crds_keep" {
  type        = bool
  default     = false
  description = "Keep the cert-manager CRDs, and with them every Certificate and ClusterIssuer, when the release is destroyed."
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
  description = "Resource requests and limits of the cert-manager controller. The default fits a demonstration cluster; the README lists production values."
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
  description = "Resource requests and limits of the cert-manager admission webhook. The default fits a demonstration cluster; the README lists production values."
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
  description = "Resource requests and limits of the cert-manager cainjector. The default fits a demonstration cluster; the README lists production values."
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
  description = "Resource requests and limits of the cert-manager startupapicheck Job."
}

variable "haproxy_version" {
  type        = string
  nullable    = false
  description = "Version of the haproxytech/kubernetes-ingress Helm chart."
}

variable "haproxy_namespace" {
  type        = string
  default     = "haproxy-ingress"
  description = "Namespace of the HAProxy ingress controller and the wildcard certificate."
}

variable "haproxy_release_name" {
  type        = string
  default     = "haproxy"
  description = "Helm release name of the HAProxy ingress controller."
}

variable "haproxy_replica_count" {
  type        = number
  nullable    = false
  description = "Number of HAProxy ingress controller replicas; production wants at least 2."
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
  description = "Resource requests and limits of the HAProxy ingress controller. The default fits a demonstration cluster; the README lists production values."
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
  description = "Resource requests and limits of the Job that installs the HAProxy CRDs."
}

variable "haproxy_service_type" {
  type = string
  # The chart defaults to NodePort, which gives no public address.
  default     = "LoadBalancer"
  description = "Service type of the HAProxy ingress controller."
}

variable "haproxy_service_annotations" {
  type        = map(string)
  nullable    = false
  description = "Annotations on the HAProxy controller Service that configure the cloud load balancer; the README lists the common ones."
}

variable "haproxy_timeout" {
  type        = number
  default     = 1200
  description = "Seconds to wait for the HAProxy release, including its cloud load balancer, to become ready."
}

variable "ingress_class_name" {
  type        = string
  nullable    = false
  description = "Name of the IngressClass the controller serves and the HTTP-01 solver uses."
}

variable "acme_email" {
  type        = string
  nullable    = false
  description = "Contact address Let's Encrypt uses for expiry warnings and account recovery."
}

variable "acme_server" {
  type        = string
  nullable    = false
  description = "ACME directory URL; use the Let's Encrypt staging directory while testing."
}

variable "cluster_issuer_name" {
  type        = string
  nullable    = false
  description = "Name of the ClusterIssuer that application teams set in the `cert-manager.io/cluster-issuer` annotation."
}

variable "acme_private_key_secret_name" {
  type        = string
  default     = "letsencrypt-prod-account-key"
  description = "Name of the secret in which cert-manager stores the ACME account private key."
}

variable "wildcard_certificate_name" {
  type        = string
  default     = "wildcard-tls"
  description = "Name of the wildcard Certificate and its secret in `haproxy_namespace`; used with `dns01`."
}

variable "stackit_webhook_version" {
  type        = string
  default     = "0.4.9"
  description = "Version of the stackit-cert-manager-webhook chart in https://stackitcloud.github.io/stackit-cert-manager-webhook; used with `dns01.stackit`."
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
  description = "Resource requests and limits of the STACKIT cert-manager webhook, used with `dns01.stackit`."
}

variable "dns01" {
  description = "DNS-01 solver with exactly one provider, for a wildcard certificate on `certificate_domain` (default `zone_name`, must lie within it). Null issues certificates per hostname over HTTP-01."
  type = object({
    zone_name          = string
    certificate_domain = optional(string)
    stackit            = optional(object({ project_id = string, service_account_key = string }))
    route53            = optional(object({ hosted_zone_id = string, access_key_id = string, secret_access_key = string, region = optional(string, "eu-central-1") }))
  })
  default   = null
  sensitive = true

  validation {
    # Both `try`s swallow reading an attribute the caller left out, which means "not this provider".
    condition = var.dns01 == null || (
      (try(var.dns01.stackit, null) == null ? 0 : 1) + (try(var.dns01.route53, null) == null ? 0 : 1) == 1
    )
    error_message = "Set exactly one DNS-01 provider in var.dns01: either stackit or route53."
  }

  # No interpolation: an error message cannot print the sensitive var.dns01.
  validation {
    # try: swallows the absent `certificate_domain` attribute, which means "default to the zone".
    condition     = var.dns01 == null || try(var.dns01.certificate_domain, null) == null || endswith(var.dns01.certificate_domain, var.dns01.zone_name)
    error_message = "dns01.certificate_domain must be dns01.zone_name or a name below it, because the DNS-01 solver only answers for names inside the zone."
  }
}

variable "imports" {
  type        = object({})
  default     = null
  description = "Set to `{}` to take over the namespaces, Helm releases and ClusterIssuer of an existing installation."
}

variable "release_on_destroy" {
  type        = bool
  nullable    = false
  default     = false
  description = "Leave the namespaces and Helm releases in place on destroy. Cannot change once they are managed."
}
