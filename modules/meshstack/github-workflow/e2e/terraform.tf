terraform {
  required_version = ">= 1.0"

  required_providers {
    meshstack = {
      source = "meshcloud/meshstack"
    }
    github = {
      source = "integrations/github"
    }
  }
}

# Needed for the per-run ephemeral branch. The same GitHub App credentials the module under test
# receives, so this adds no inputs of its own.
provider "github" {
  owner = var.test_context.fixtures.github.owner

  app_auth {
    id              = var.github_app_id
    installation_id = var.github_app_installation_id
    pem_file        = var.github_app_private_key
  }
}
