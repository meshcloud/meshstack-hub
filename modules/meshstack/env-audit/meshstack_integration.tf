variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    tags                        = optional(map(list(string)), {})
  })
  description = "Shared meshStack context. Tags are optional and propagated to building block definition metadata."
}

variable "hub" {
  type = object({
    git_ref   = optional(string, "main")
    bbd_draft = optional(bool, true)
  })
  const       = true
  default     = {}
  description = <<-EOT
  `git_ref`: Hub release reference. Set to a tag (e.g. 'v1.2.3') or branch or commit sha of the meshstack-hub repo.
  `bbd_draft`: If true, the building block definition version is kept in draft mode.
  EOT
}

output "building_block_definition" {
  description = "BBD is consumed in building block compositions."
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name = "meshStack Environment Variable Audit"
    description  = "Validates that the building block runner provides a clean, minimal environment with no unexpected environment variables."
    target_type  = "WORKSPACE_LEVEL"
    readme       = <<-MARKDOWN
      This building block verifies that the building block runner exposes only the expected set of
      environment variables. It acts as a canary test for the runner's environment isolation guarantees.

      ## How it works

      The pre-run script runs after `tofu init` and before `tofu apply`. It:
      - Enumerates all currently set environment variables
      - Checks each one against a fixed allowlist
      - Fails with a descriptive error surfaced to the user if any unexpected variable is found

      This building block provisions no cloud resources — the audit is its sole purpose.

      ## Shared Responsibility

      | Task | Platform Team | Application Team |
      |------|:---:|:---:|
      | Configure building block runner environment | ✅ | ❌ |
      | Review unexpected variable findings | ✅ | ❌ |
      | Trigger building block execution | ❌ | ✅ |
    MARKDOWN
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "PURGE"
    implementation = {
      terraform = {
        ref_name          = var.hub.git_ref
        repository_path   = "modules/meshstack/env-audit/buildingblock"
        repository_url    = "https://github.com/meshcloud/meshstack-hub.git"
        terraform_version = "1.11.0"
        pre_run_script    = file("${path.module}/buildingblock/prerun.sh")
      }
    }
    inputs = {}
    outputs = {
      audit_result = {
        assignment_type = "NONE"
        display_name    = "Audit Result"
        type            = "STRING"
      }
    }
  }
}

terraform {
  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = "~> 0.20.0"
    }
  }
}
