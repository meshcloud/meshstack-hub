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
  description = <<-EOT
  Resource requests and limits of the cert-manager controller. The default is sized for a
  demonstration cluster and a production consumer has to raise it.

  The cert-manager Helm chart sets no resources at all and documents `10m` CPU and `32Mi` memory
  as its example request. The memory request here is `64Mi` instead, because the controller keeps
  informer caches for Certificates, Secrets and Ingresses and a container that runs out of memory
  is OOMKilled rather than slowed down. A cluster that issues certificates continuously wants
  `100m` CPU and `512Mi` memory.
  EOT
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
  description = <<-EOT
  Resource requests and limits of the cert-manager admission webhook. The default is sized for a
  demonstration cluster and a production consumer has to raise it.

  The webhook validates cert-manager objects and holds no cache, so it is the smallest of the
  three cert-manager pods. Every apply that touches a Certificate or an Issuer goes through it,
  so keep the limit above the request. A production cluster wants `100m` CPU and `256Mi` memory.
  EOT
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
  description = <<-EOT
  Resource requests and limits of the cert-manager cainjector. The default is sized for a
  demonstration cluster and a production consumer has to raise it.

  The cainjector watches every Secret in the cluster, so its memory grows with the number of
  Secrets. cert-manager issue #6217 reports it reaching gigabytes on large clusters. The limit
  here is `256Mi` because a demonstration cluster holds few Secrets, and a production cluster
  wants `512Mi` or more together with the `--namespace` flag that narrows the watch.
  EOT
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
  description = <<-EOT
  Resource requests and limits of the cert-manager startupapicheck Job. The default is sized for
  a demonstration cluster and a production consumer has to raise it.

  The Job runs once per install, checks that the webhook answers and then exits, so it never
  holds resources for long. Its request still has to fit on a node, which is why it is kept this
  small.
  EOT
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
  # The chart defaults to 2. One replica is enough to serve traffic and it halves what the
  # controller costs on a demonstration cluster.
  default     = 1
  description = "Number of HAProxy ingress controller replicas. The default of 1 is sized for a demonstration cluster and gives no redundancy: every restart or node drain interrupts ingress traffic. Production wants at least 2, spread over separate nodes."
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
  description = <<-EOT
  Resource requests and limits of the HAProxy ingress controller. The default is sized for a
  demonstration cluster and a production consumer has to raise it.

  The chart requests `250m` CPU and `400Mi` memory and sets no limit. The pod runs two processes,
  HAProxy itself and the Go controller, and the container entrypoint hands HAProxy two thirds of
  the cgroup memory limit. Users of this chart version report that HAProxy reloads in a loop
  instead of serving traffic when the memory limit stays below `500Mi`, and a maintainer
  recommends at least `1Gi` (haproxytech/kubernetes-ingress issue #799). The `768Mi` limit here is
  the smallest value that clears that threshold with headroom. Production wants `1Gi` to `2Gi`
  and a CPU limit that matches the traffic the controller has to terminate.
  EOT
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
  description = <<-EOT
  Resource requests and limits of the Job the HAProxy chart runs to install its CRDs. The default
  is sized for a demonstration cluster and a production consumer has to raise it.

  The chart requests `250m` CPU and `400Mi` memory for this Job. The Job applies a handful of
  CRDs and exits, so a much smaller request is enough, and a smaller request also means the Job
  still schedules on a small node.
  EOT
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

# The default follows the published chart index rather than the GitHub release tags, because the
# two diverged: the repository tagged a `stackit-cert-manager-webhook-0.4.10` release, but
# https://stackitcloud.github.io/stackit-cert-manager-webhook/index.yaml was never regenerated and
# still ends at 0.4.9. `helm_release` resolves the version through that index, so pinning 0.4.10
# fails at apply with "no chart version found". Raise this default only after the index serves the
# newer version.
variable "stackit_webhook_version" {
  type        = string
  default     = "0.4.9"
  description = "Version of the stackit-cert-manager-webhook Helm chart. Must be a version served by the chart index at https://stackitcloud.github.io/stackit-cert-manager-webhook, which lags behind the GitHub release tags. Only used when dns01.stackit is set."
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
  description = <<-EOT
  Resource requests and limits of the STACKIT cert-manager webhook. Only used when dns01.stackit
  is set. The default is sized for a demonstration cluster and a production consumer has to raise
  it.

  The chart sets no resources and its values file states that `100m` CPU and `128Mi` memory are
  enough for the webhook, which is what the limit uses. The webhook answers one DNS-01 challenge
  per certificate renewal, so the request stays well below that. Production wants the chart's own
  figures as the request as well.
  EOT
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
