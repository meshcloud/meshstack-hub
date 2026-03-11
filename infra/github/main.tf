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

resource "github_repository_ruleset" "protect_default_branch" {
  enforcement = "active"
  name        = "Protect Default"
  repository  = local.github_repository_name
  target      = "branch"
  bypass_actors {
    actor_id    = 0
    actor_type  = "DeployKey"
    bypass_mode = "always"
  }
  bypass_actors {
    actor_id    = 2
    actor_type  = "RepositoryRole"
    bypass_mode = "always"
  }
  conditions {
    ref_name {
      exclude = []
      include = ["~DEFAULT_BRANCH"]
    }
  }
  rules {
    creation                      = false
    deletion                      = true
    non_fast_forward              = true
    required_linear_history       = true
    required_signatures           = false
    update                        = false
    update_allows_fetch_and_merge = false
    pull_request {
      allowed_merge_methods             = ["rebase"]
      dismiss_stale_reviews_on_push     = false
      require_code_owner_review         = false
      require_last_push_approval        = false
      required_approving_review_count   = 1
      required_review_thread_resolution = true
    }
  }
}
