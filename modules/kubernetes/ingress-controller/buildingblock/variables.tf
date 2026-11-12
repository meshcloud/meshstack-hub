variable "cert_manager_namespace" {
  type        = string
  default     = "cert-manager"
  description = "Namespace of cert-manager."
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

variable "haproxy_namespace" {
  type        = string
  default     = "haproxy-ingress"
  description = "Namespace of the HAProxy ingress controller and of the wildcard certificate."
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
    requests = { cpu = "20m", memory = "64Mi" }
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
    requests = { cpu = "10m", memory = "32Mi" }
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

variable "use_letsencrypt_staging" {
  type        = bool
  nullable    = false
  default     = false
  description = "Issue from Let's Encrypt staging, for development and testing. No browser trusts its certificates."
}

variable "cluster_issuer_name" {
  type        = string
  nullable    = false
  description = "Name of the ClusterIssuer that application teams set in the `cert-manager.io/cluster-issuer` annotation."
}

variable "acme_private_key_secret_name" {
  type        = string
  default     = null
  description = "Name of the secret in which cert-manager stores the ACME account private key. Null names it after the Let's Encrypt environment."
}

variable "dns01" {
  type = object({
    domain = string
    solver = any
  })
  default     = null
  description = "If null, cert-manager issues one certificate per Ingress over HTTP-01. If set, it issues the wildcard certificate `*.<domain>` over DNS-01 with `solver`, the `dns01` block of a cert-manager ACME solver, and HAProxy serves it as its default certificate to every Ingress."
}

variable "wildcard_certificate_name" {
  type        = string
  nullable    = false
  default     = "wildcard-tls"
  description = "Name of the wildcard Certificate and its secret in `haproxy_namespace`; used with `dns01`."
}

variable "imports" {
  type        = object({})
  default     = null
  description = "Set to `{}` to take over the namespaces, Helm releases and ClusterIssuer of an existing installation."
}

variable "release_on_destroy" {
  type        = bool
  nullable    = false
  description = "Leave the namespaces and Helm releases in place on destroy. Cannot change once they are managed."
}
