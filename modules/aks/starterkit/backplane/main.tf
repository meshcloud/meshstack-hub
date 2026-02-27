module "github_repo_bbd" {
  source = "github.com/meshcloud/meshstack-hub//modules/github/repository?ref=feature/aks-starter-kit-refactoring" # will be updated by CI once merged to main

  hub       = var.hub
  meshstack = var.meshstack
  github = {
    org                 = var.github.org
    app_id              = var.github.app_id
    app_installation_id = var.github.app_installation_id
    app_pem_file        = var.github.app_pem_file
  }
}

module "github_connector_bbd" {
  source = "github.com/meshcloud/meshstack-hub//modules/aks/github-connector?ref=feature/aks-starter-kit-refactoring"

  hub       = var.hub
  meshstack = var.meshstack
  github    = var.github
  github_repo_bbd = {
    uuid = module.github_repo_bbd.bbd_uuid
  }
}

module "postgresql_bbd" {
  count  = var.postgresql != null ? 1 : 0
  source = "github.com/meshcloud/meshstack-hub//modules/azure/postgresql?ref=feature/aks-starter-kit-refactoring"

  hub       = var.hub
  meshstack = var.meshstack
}
