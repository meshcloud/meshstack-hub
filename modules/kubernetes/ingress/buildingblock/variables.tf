variable "cert_manager_version" {
  type        = string
  default     = "v1.20.0"
  description = "Version of the cert-manager Helm chart. See https://github.com/cert-manager/cert-manager/releases."
}

variable "cert_manager_namespace" {
  type        = string
  default     = "cert-manager"
  description = "Namespace for cert-manager and, when DNS-01 runs through STACKIT, for the STACKIT cert-manager webhook. The webhook chart expects both in the same namespace."
}

variable "cert_manager_extra_args" {
  type = list(string)
  # Cuts the retry backoff for failed certificate requests from the default 1h down to 1m, so an
  # ACME order recovers quickly after a transient DNS or ingress problem.
  default     = ["--certificate-request-minimum-backoff-duration=1m"]
  description = "Extra command line arguments for the cert-manager controller."
}

variable "cert_manager_crds_keep" {
  type        = bool
  default     = false
  description = "Keep the cert-manager CRDs when the Helm release is destroyed. Keeping them preserves existing Certificate and ClusterIssuer objects across a reinstall."
}

variable "haproxy_version" {
  type        = string
  default     = "1.49.0"
  description = "Version of the haproxytech/kubernetes-ingress Helm chart. See https://github.com/haproxytech/helm-charts/blob/main/kubernetes-ingress/Chart.yaml."
}

variable "haproxy_namespace" {
  type        = string
  default     = "haproxy-ingress"
  description = "Namespace for the HAProxy ingress controller. The wildcard certificate is created here as well, so its secret survives the teardown of any application namespace."
}

variable "haproxy_release_name" {
  type        = string
  default     = "haproxy"
  description = "Helm release name of the HAProxy ingress controller. The chart names the controller Service '<release>-kubernetes-ingress'."
}

variable "haproxy_replica_count" {
  type = number
  # Equals the chart default. It is exposed so a foundation can scale the controller without
  # having to reach into the chart values.
  default     = 2
  description = "Number of HAProxy ingress controller replicas."
}

variable "haproxy_service_type" {
  type = string
  # The chart defaults to NodePort, which gives no public address at all, so this value is
  # load-bearing rather than cosmetic.
  default     = "LoadBalancer"
  description = "Service type of the HAProxy ingress controller."
}

variable "haproxy_service_annotations" {
  type        = map(string)
  default     = {}
  description = <<-EOT
  Annotations on the HAProxy controller Service. The cloud provider reads them to configure the
  load balancer. Two values matter in practice:
  - AKS needs `service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path = "/healthz"`.
  - STACKIT uses `lb.stackit.cloud/internal-lb` to keep the load balancer off the public internet.
  EOT
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

variable "acme_email" {
  type        = string
  description = "Contact address Let's Encrypt uses for expiry warnings and account recovery."
}

variable "acme_server" {
  type        = string
  default     = "https://acme-v02.api.letsencrypt.org/directory"
  description = "ACME directory URL. Point this at https://acme-staging-v02.api.letsencrypt.org/directory while you test, because the production endpoint has strict rate limits."
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

variable "wildcard_certificate_name" {
  type        = string
  default     = "wildcard-tls"
  description = "Name of the wildcard Certificate and of the secret it writes, both in haproxy_namespace. Only used when dns01 is set."
}

variable "stackit_webhook_version" {
  type        = string
  default     = "0.4.10"
  description = "Version of the stackit-cert-manager-webhook Helm chart. Only used when dns01.stackit is set. See https://github.com/stackitcloud/stackit-cert-manager-webhook."
}

variable "dns01" {
  description = "Enables a wildcard certificate for zone_name via DNS-01. Set exactly one provider. Null keeps HTTP-01 per-hostname issuance."
  type = object({
    zone_name = string
    stackit   = optional(object({ project_id = string, service_account_key = string }))
    route53   = optional(object({ hosted_zone_id = string, access_key_id = string, secret_access_key = string, region = optional(string, "eu-central-1") }))
  })
  default   = null
  sensitive = true

  validation {
    condition = var.dns01 == null || (
      (try(var.dns01.stackit, null) == null ? 0 : 1) + (try(var.dns01.route53, null) == null ? 0 : 1) == 1
    )
    error_message = "Set exactly one DNS-01 provider in var.dns01: either stackit or route53."
  }
}
