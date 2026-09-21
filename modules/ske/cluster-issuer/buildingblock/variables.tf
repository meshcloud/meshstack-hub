variable "kubeconfig" {
  type        = string
  sensitive   = true
  nullable    = false
  description = "Raw kubeconfig (YAML) of the SKE cluster to install the ClusterIssuer on. cert-manager must already be installed on it (its CRDs are looked up at plan time)."
}

variable "cluster_issuer_email" {
  type        = string
  nullable    = false
  default     = "ske@meshcloud.io"
  description = "Contact email registered with Let's Encrypt for the ACME ClusterIssuer."
}

variable "ingress_class_name" {
  type        = string
  nullable    = false
  default     = "haproxy"
  description = "Ingress class the ACME HTTP-01 solver routes challenges through."
}
