variable "cluster_name" {
  type        = string
  nullable    = false
  description = "Name of the cluster and context in the deployer kubeconfig."
}

variable "cluster_server" {
  type        = string
  nullable    = false
  description = "API server URL of the cluster the `kubernetes` provider points at, e.g. `https://api.example.com:6443`."
}

variable "cluster_roles" {
  type        = list(string)
  nullable    = false
  description = "ClusterRoles the deployer may bind ordered service accounts to."
}

variable "bind_cluster_wide" {
  type        = bool
  nullable    = false
  description = "Let the deployer create ClusterRoleBindings, which bind a role in every namespace."
}

variable "service_account_name" {
  type        = string
  nullable    = false
  description = "Name of the deployer service account, its token secret, ClusterRole and ClusterRoleBinding."
}

variable "namespace" {
  type        = string
  nullable    = false
  description = "Namespace of the deployer service account and its token secret."
}
