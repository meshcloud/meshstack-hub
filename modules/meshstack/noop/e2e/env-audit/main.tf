resource "meshstack_building_block_definition" "env_audit" {
  metadata = {
    owned_by_workspace = var.test_context.workspace
    tags               = {}
  }

  spec = {
    display_name = "meshStack Environment Variable Audit"
    description  = "Captures environment variable keys at pre-run and apply time so tftest can assert on the runner's environment isolation."
    target_type  = "WORKSPACE_LEVEL"
    readme = chomp(<<-MARKDOWN
      This building block captures the environment variable keys visible to the
      building block runner at two points in time: during the pre-run script and
      during `tofu apply`. It provisions no cloud resources.

      Use it as a test fixture to verify that the runner's environment isolation
      is working correctly — no unexpected variables should be present.

      ## Shared Responsibility

      | Task | Platform Team | Application Team |
      |------|:---:|:---:|
      | Configure building block runner environment | ✅ | ❌ |
      | Review env key outputs | ✅ | ❌ |
      | Trigger building block execution | ❌ | ✅ |
    MARKDOWN
    )
  }

  version_spec = {
    draft         = true
    deletion_mode = "PURGE"
    implementation = {
      terraform = {
        ref_name          = var.test_context.hub_git_ref
        repository_path   = "modules/meshstack/noop/e2e/env-audit/buildingblock"
        repository_url    = "https://github.com/meshcloud/meshstack-hub.git"
        terraform_version = "1.11.0"
        pre_run_script    = file("${path.module}/buildingblock/prerun.sh")
      }
    }
    inputs = {}
    outputs = {
      prerun_env_keys = {
        assignment_type = "NONE"
        display_name    = "Pre-run Environment Keys"
        type            = "STRING"
      }
      apply_env_keys = {
        assignment_type = "NONE"
        display_name    = "Apply-time Environment Keys"
        type            = "STRING"
      }
    }
  }
}

resource "meshstack_building_block" "this" {
  wait_for_completion = true
  spec = {
    building_block_definition_version_ref = meshstack_building_block_definition.env_audit.version_latest

    display_name = "smoke-test-env-audit-${var.test_context.name_suffix}"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }
    inputs = {}
  }
}
