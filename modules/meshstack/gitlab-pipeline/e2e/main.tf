variable "test_context" {
  type = object({
    hub_git_ref = string
    workspace   = string
    project     = string
    run_id      = string

    fixtures = object({
      gitlab = object({
        project_id = string

        # Branch carrying the pipeline file. Committed by hand, so every run triggers the same one —
        # harmless, because a trigger starts a pipeline of its own rather than mutating the branch.
        branch = optional(string, "main")
      })
    })
  })
  nullable = false
}

# A root variable rather than a `test_context` field: the runner exports every secret as
# TF_VAR_<name>, so it does not have to travel through the grab-bag.
variable "gitlab_pipeline_trigger_token" {
  type      = string
  sensitive = true
  nullable  = false
}

module "gitlab_pipeline" {
  source = "../"

  bbd_display_name         = "${var.test_context.run_id} meshStack GitLab Pipeline NoOp"
  integration_display_name = "${var.test_context.run_id} GitLab Integration"

  gitlab_pipeline_trigger_token = var.gitlab_pipeline_trigger_token
  gitlab_project_id             = var.test_context.fixtures.gitlab.project_id
  gitlab_branch                 = var.test_context.fixtures.gitlab.branch

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
  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = module.gitlab_pipeline.building_block_definition.version_ref

    display_name = "${var.test_context.run_id}-gitlab-pipeline"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    inputs = {
      text = { value = jsonencode("Hello, World!") }
      num  = { value = jsonencode(1) }
      flag = { value = jsonencode(true) }

      single_select = { value = jsonencode("single1") }
      multi_select  = { value = jsonencode(["multi1", "multi2"]) }

      # A JSON input reaches the pipeline as JSON text, so its value is encoded twice like a CODE one.
      json_form = { value = jsonencode(jsonencode({ region = "eu-central-1", replicas = 2 })) }

      sensitive_text = { sensitive = { secret_value = "Hidden value" } }

      # Settable here because the test key owns the definition; an app team could not fill this in.
      operator_text = { value = jsonencode("Set by the platform operator") }

      # optional_text is deliberately omitted, and conditional_text cannot be set at all while flag
      # is true. Neither reaches the pipeline, which is what the test asserts.
    }
  }
}

# The two echo documents, decoded once for the outputs map and once for the CODE payload inside it.
output "from_run_object" {
  description = "Inputs as the pipeline read them from the run object."
  # Swallows a run that produced no outputs at all, so the SUCCEEDED assertion below reports the
  # real failure instead of this decode erroring first.
  value = try(jsondecode(jsondecode(meshstack_building_block.this.status.outputs["received_from_run_object_json"].value)), {})
}

output "from_trigger" {
  description = "Inputs as the pipeline trigger delivered them."
  # Swallows a missing output for the same reason as above.
  value = try(jsondecode(jsondecode(meshstack_building_block.this.status.outputs["received_from_trigger_json"].value)), {})
}
