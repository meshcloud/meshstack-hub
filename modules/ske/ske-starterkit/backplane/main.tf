variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
  })
}

variable "hub" {
  type = object({
    git_ref   = string
    bbd_draft = bool
  })
}

variable "forgejo_token" {
  type      = string
  sensitive = true
}

variable "forgejo_organization" {
  type = string
}

variable "forgejo_base_url" {
  type = string
}

variable "cluster_host" {
  type        = string
  description = "The endpoint of the Kubernetes cluster."
}

variable "cluster_ca_certificate" {
  type        = string
  sensitive   = true
  description = "Base64-encoded certificate authority (CA) certificate used to verify the Kubernetes API server's identity."
}

variable "client_certificate" {
  type        = string
  sensitive   = true
  description = "Base64-encoded client certificate used for authenticating to the Kubernetes API server."
}

variable "client_key" {
  type        = string
  sensitive   = true
  description = "Base64-encoded private key corresponding to the client certificate, used for authentication with the Kubernetes API server."
}

variable "cluster_kubeconfig" {
  type        = string
  sensitive   = true
  description = "Raw kubeconfig content containing the configuration required to access and authenticate to the Kubernetes cluster."
}

variable "harbor_host" {
  type        = string
  description = "The URL of the Harbor registry."
  default     = "https://registry.onstackit.cloud"
}

variable "harbor_username" {
  type        = string
  sensitive   = true
  description = "The username for the Harbor registry."
}

variable "harbor_password" {
  type        = string
  sensitive   = true
  description = "The password for the Harbor registry."
}

output "building_block_definition_version_refs" {
  value = {
    "git-repository" : module.git_repository.building_block_definition_version_ref
    "forgejo-connector" : module.forgejo_connector.building_block_definition_version_ref
  }
}

module "git_repository" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/git-repository?ref=25e0907d1ccc5ee85e671121397e0fa55b6e92df"

  meshstack = var.meshstack
  hub       = var.hub

  forgejo_token        = var.forgejo_token
  forgejo_organization = var.forgejo_organization
  forgejo_base_url     = var.forgejo_base_url
}

module "forgejo_connector" {
  source = "github.com/meshcloud/meshstack-hub//modules/ske/forgejo-connector?ref=feature/stackit-git-connect"

  meshstack = var.meshstack
  hub       = var.hub

  cluster_host           = var.cluster_host
  cluster_ca_certificate = var.cluster_ca_certificate
  client_certificate     = var.client_certificate
  client_key             = var.client_key
  cluster_kubeconfig     = var.cluster_kubeconfig
  forgejo_host           = var.forgejo_base_url
  forgejo_api_token      = var.forgejo_token
  harbor_host            = var.harbor_host
  harbor_username        = var.harbor_username
  harbor_password        = var.harbor_password

  forgejo_repo_definition_uuid = module.git_repository.building_block_definition_uuid
}
