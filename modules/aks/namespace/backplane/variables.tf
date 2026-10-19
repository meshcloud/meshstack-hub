variable "name" {
  type        = string
  nullable    = false
  description = "Name for the building block identity and role definition."
  validation {
    condition     = can(regex("^[-a-z0-9]+$", var.name))
    error_message = "Only alphanumeric lowercase characters and dashes are allowed."
  }
}

variable "scope" {
  type        = string
  nullable    = false
  description = "Scope the custom role definition is assignable at (management group or subscription ID). Must contain the AKS cluster."
}

variable "location" {
  type        = string
  nullable    = false
  description = "Azure region for the UAMI resource."
}

variable "workload_identity_federation" {
  type = object({
    issuer   = string
    subjects = list(string)
  })
  nullable    = false
  description = "WIF issuer and subjects for federated authentication."
}

variable "aks" {
  type = object({
    cluster_name        = string
    resource_group_name = string
  })
  nullable    = false
  description = "The existing AKS cluster namespaces are created in. It must have Azure RBAC for Kubernetes authorization enabled."
}

variable "acr_id" {
  type        = string
  default     = null
  description = "Resource ID of the Azure Container Registry the cluster's workloads pull images from. When set, the cluster's kubelet identity gets AcrPull on it, so no namespace needs an image pull secret."
}
