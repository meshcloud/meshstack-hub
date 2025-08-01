variable "resource_group_name" {
  type    = string
  default = "aks-prod-rg"
}

variable "location" {
  type    = string
  default = "Germany West Central"
}

variable "aks_cluster_name" {
  type    = string
  default = "prod-aks"
}

variable "dns_prefix" {
  type    = string
  default = "prodaks"
}

variable "agent_count" {
  type    = number
  default = 3
}

variable "vm_size" {
  type    = string
  default = "Standard_DS3_v2"
}

variable "kubernetes_version" {
  type    = string
  default = "1.29.2"
}

variable "aks_admin_group_object_id" {
  type        = string
  description = "Object ID of the Azure AD group used for AKS admin access"
}

