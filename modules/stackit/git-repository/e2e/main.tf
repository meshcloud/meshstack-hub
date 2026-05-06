variable "test_context" {
  type = object({
    workspace            = string
    name_suffix          = string
    forgejo_base_url     = string
    forgejo_organization = string
  })
  nullable = false
}

variable "stackit_git_forgejo_token" {
  type      = string
  nullable  = false
  sensitive = true
}

module "stackit_git_repository" {
  source = "github.com/meshcloud/meshstack-hub/modules/stackit/git-repository"
  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags = {
      "BBEnvironment" = ["dev"]
    }
  }
  hub = {
    git_ref   = "main"
    bbd_draft = true
  }

  forgejo_base_url     = var.test_context.forgejo_base_url
  forgejo_token        = var.stackit_git_forgejo_token
  forgejo_organization = var.test_context.forgejo_organization
}

resource "meshstack_building_block_v2" "this" {
  wait_for_completion = true
  spec = {
    building_block_definition_version_ref = {
      uuid = module.stackit_git_repository.building_block_definition.version_ref.uuid
    }

    display_name = "smoke-test-stackit-git-repository-hub-${var.test_context.name_suffix}"
    target_ref = {
      kind       = "meshWorkspace"
      identifier = var.test_context.workspace
    }

    inputs = {
      name        = { value_string = "smoke-test-repo-${var.test_context.name_suffix}" }
      description = { value_string = "Smoke test repository" }
      private     = { value_bool = true }
      clone_addr  = { value_string = "https://github.com/likvid-bank/starterkit-template-stackit-ai-summarizer.git" }
    }
  }
}
