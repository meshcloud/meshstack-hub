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

output "building_block_definition_version_refs" {
  value = {
    "git-repository" : module.git_repository.building_block_definition_version_ref
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
