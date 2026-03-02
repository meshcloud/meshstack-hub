# k8s
variable "cluster_endpoint" {
  type        = string
  description = "API endpoint of the cluster"
}

variable "cluster_config_path" {
  type        = string
  description = "Path to the kubeconfig file"
}

variable "cluster_config_context" {
  type        = string
  description = "Kubeconfig context to use"
}

variable "namespace" {
  type = string
}

variable "cluster_ca_certificate" {
  type        = string
  description = "Cluster CA certificate, base64 encoded"
}

variable "context" {
  type        = string
  description = "Defines which cluster to interact with. Can be any name"
}

variable "token" {
  type        = string
  sensitive   = true
  description = "Token for the service account executing this module (not this service account)"
}

variable "sa_name" {
  type        = string
  description = "Service Account Name for k8s Service Account"
}

variable "sa_cluster_role" {
  type        = string
  description = "Cluster Role for k8s Service Account"
}

# harbor
variable "harbor_endpoint" {
  type        = string
  description = "Harbor API endpoint"
}

variable "harbor_username" {
  type        = string
  description = "Harbor username for authentication"
}

variable "harbor_password" {
  type        = string
  sensitive   = true
  description = "Harbor password for authentication"
}

variable "harbor_project_id" {
  type      = string
  sensitive = true
}