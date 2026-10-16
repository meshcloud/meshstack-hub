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

variable "context" {
  type        = string
  description = "Defines which cluster to interact with. Can be any name"
}

variable "cluster_role" {
  type        = string
  description = "ClusterRole to bind the service account with. e.g. admin, edit, view (or any custom cluster role)"
}

variable "bind_cluster_wide" {
  type        = bool
  nullable    = false
  default     = false
  description = "Grant `cluster_role` in every namespace through a ClusterRoleBinding, instead of in `namespace` only through a RoleBinding."
}

variable "output_to_vault" {
  type = object({
    address  = string
    mount    = string
    username = string
    password = string
    path     = string
  })
  default     = null
  sensitive   = true
  description = "Vault KV v2 secret this building block writes its secrets to instead of returning them as outputs: the server `address`, the engine `mount`, a userpass `username` and `password`, and the secret `path`. Null returns them as outputs."
}
