variable "kubeconfig" {
  type        = string
  sensitive   = true
  description = "Raw kubeconfig (YAML) of the SKE cluster this runs against — the `kubeconfig` output of the STACKIT SKE Cluster building block. The kubernetes and helm providers are configured from it, so it must be a concrete value at plan time (i.e. supplied by a preceding building block, not created in this run)."
}

variable "cluster_issuer_email" {
  type        = string
  default     = "ske@meshcloud.io"
  description = "Contact email registered with Let's Encrypt for the ACME ClusterIssuer."
}

variable "cert_manager_version" {
  type        = string
  default     = "v1.20.0"
  description = "cert-manager Helm chart version."
}

variable "haproxy_version" {
  type        = string
  default     = "1.49.0"
  description = "HAProxy Kubernetes Ingress Helm chart version."
}

variable "haproxy_replica_count" {
  type        = number
  default     = 2
  description = "Number of HAProxy ingress controller replicas."
}
