variable "test_context" {
  type = object({
    hub_git_ref = string
    workspace   = string
    project     = string
    run_id      = string

    fixtures = object({
      azuredevops = object({
        organization  = string
        project       = string
        repository_id = string
        pipeline_id   = string

        branch = optional(string, "refs/heads/main")
      })
    })
  })
  nullable = false
}

variable "azuredevops_personal_access_token" {
  type      = string
  sensitive = true
  nullable  = false
}

locals {
  ephemeral_branch = "${var.test_context.run_id}/azure-devops-pipeline"
}

# Per-run ephemeral branch. The backplane's job is to commit the pipeline file into the target repository
resource "azuredevops_git_repository_branch" "ephemeral" {
  repository_id = var.test_context.fixtures.azuredevops.repository_id
  name          = local.ephemeral_branch
  ref_branch    = var.test_context.fixtures.azuredevops.branch
}

module "azure_devops_pipeline" {
  source = "../"

  bbd_display_name         = "${var.test_context.run_id} Azure DevOps Pipeline Building Block"
  integration_display_name = "${var.test_context.run_id} Azure DevOps Integration"

  azuredevops_organization          = var.test_context.fixtures.azuredevops.organization
  azuredevops_project               = var.test_context.fixtures.azuredevops.project
  azuredevops_personal_access_token = var.azuredevops_personal_access_token
  azuredevops_repository_id         = var.test_context.fixtures.azuredevops.repository_id
  azuredevops_pipeline_id           = var.test_context.fixtures.azuredevops.pipeline_id
  azuredevops_ref_name              = "refs/heads/${azuredevops_git_repository_branch.ephemeral.name}"

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }

  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }
}

resource "meshstack_building_block" "this" {
  depends_on = [module.azure_devops_pipeline, azuredevops_git_repository_branch.ephemeral]

  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = module.azure_devops_pipeline.building_block_definition.version_ref

    display_name = "${var.test_context.run_id}-azure-devops-pipeline"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    inputs = {
      environment = {
        value = jsonencode("dev")
      }
    }
  }
}
