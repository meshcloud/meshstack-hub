module "git_repo_bbd" {
  source = "../../../git-repository"

  owning_workspace_identifier = var.meshstack.owning_workspace_identifier
  meshstack_hub_git_ref       = var.hub.git_ref
  gitea_base_url              = var.gitea.base_url
  gitea_token                 = var.gitea.token
  gitea_organization          = var.gitea.organization
}

module "forgejo_connector_bbd" {
  source = "../../forgejo-connector"

  hub       = var.hub
  meshstack = var.meshstack
  gitea     = var.gitea
  ske       = var.ske
  harbor    = var.harbor
  git_repo_bbd = {
    uuid = module.git_repo_bbd.bbd_uuid
  }
}
