variable "test_context" {
  # Untyped: each mode module re-types it strictly, so every field it needs stays required.
  type     = any
  nullable = false

  validation {
    condition     = can(var.test_context.workspace) && can(var.test_context.run_id)
    error_message = "test_context must provide workspace and run_id."
  }

  validation {
    # `try` because `test_context` is untyped, so a hub run need not set `mode` at all.
    condition     = contains(["hub", "foundation"], try(var.test_context.mode, "hub"))
    error_message = "test_context.mode must be \"hub\" (the default) or \"foundation\"."
  }
}

# Secrets never travel in `test_context`. They arrive as TF_VAR_*, which only the root module sees.
variable "stackit_git_forgejo_api_token" {
  type      = string
  sensitive = true
  default   = null
}

locals {
  # `try` because `test_context` is untyped, so a hub run need not set `mode` at all.
  mode = try(var.test_context.mode, "hub")
}

module "definition" {
  source = "./modes/${local.mode}"

  test_context = var.test_context

  backplane_secrets = {
    stackit_git_forgejo_api_token = var.stackit_git_forgejo_api_token
  }
}

resource "meshstack_building_block" "this" {
  # Also orders teardown: the delete run still reads the secrets the hub mode writes.
  depends_on = [module.definition]

  wait_for_completion = true
  spec = {
    building_block_definition_version_ref = module.definition.version_ref

    display_name = "${var.test_context.run_id}-git-repository"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    inputs = {
      name        = { value = jsonencode("${var.test_context.run_id}-repo") }
      description = { value = jsonencode("Smoke test repository") }
      private     = { value = jsonencode(true) }
      clone_addr  = { value = jsonencode("https://github.com/likvid-bank/starterkit-template-stackit-ai-summarizer.git") }
    }
  }
}
