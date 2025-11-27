variable "name" {
  type        = string
  description = "Service account name"
}

variable "namespace" {
  type        = string
  description = "Namespace where the service account will be created. Recommended: Use platform tenant ID as input in meshStack"
}

variable "cluster_name" {
  type        = string
  description = "Name of the k8s cluster hosting this service account"
}

variable "cluster_endpoint" {
  type        = string
  description = "IP address of the cluster control plane"
}

variable "cluster_ca_certificate" {
  type        = string
  description = "Cluster CA certificate, base64 encoded"
}

variable "context" {
  type        = string
  description = "Defines which cluster to interact with. Can be any name"
}

variable "cluster_role" {
  type        = string
  description = "ClusterRole to bind the service account with. e.g. admin, edit, view (or any custom cluster role)"
}

variable "token" {
  type        = string
  sensitive   = true
  description = "Token for the service account executing this module (not this service account)"
}
