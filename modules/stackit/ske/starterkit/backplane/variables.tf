variable "hub" {
  type = object({
    git_ref = string
  })
  description = "Hub release reference. Set git_ref to a tag (e.g. 'v1.2.3') or branch for the meshstack-hub repo."
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
  })
  description = "Shared meshStack context passed down from the IaC runtime."
}

variable "gitea" {
  type = object({
    base_url     = string
    token        = string
    organization = string
  })
  sensitive   = true
  description = "STACKIT Git (Forgejo) credentials and organization."
}

variable "ske" {
  type = object({
    cluster_server         = string
    cluster_ca_certificate = string
  })
  description = "SKE cluster connection details for kubeconfig generation in the Forgejo connector."
}

variable "harbor" {
  type = object({
    url            = string
    robot_username = string
    robot_token    = string
  })
  sensitive   = true
  default     = null
  description = "Harbor registry credentials. When provided, stores push credentials as Forgejo Actions secrets and creates an image pull secret in each namespace."
}
