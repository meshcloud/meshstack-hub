locals {
  github_repository_name = "meshstack-hub"
}

# Generate an ssh key using provider "hashicorp/tls"
resource "tls_private_key" "deploy_key" {
  algorithm = "ED25519"
}

resource "github_repository_environment" "main" {
  repository  = local.github_repository_name
  environment = "main"
  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment_deployment_policy" "main" {
  repository     = local.github_repository_name
  environment    = github_repository_environment.main.environment
  branch_pattern = "main"
}

# Add the ssh key as a deploy key
resource "github_repository_deploy_key" "deploy_key" {
  title      = "Repo write access from CI (managed as-code in infra/github folder)"
  repository = local.github_repository_name
  key        = tls_private_key.deploy_key.public_key_openssh
  read_only  = false
}

resource "github_actions_environment_secret" "deploy_key" {
  repository      = local.github_repository_name
  environment     = github_repository_environment.main.environment
  secret_name     = "REPO_DEPLOY_KEY"
  plaintext_value = tls_private_key.deploy_key.private_key_openssh
}
