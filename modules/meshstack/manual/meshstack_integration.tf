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
    git_ref     = var.hub.git_ref
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name = "meshStack Manual Building Block"
    description  = "Reference building block demonstrating the MANUAL implementation type: the backend derives one output per input (SINGLE_SELECT is mirrored as STRING), so outputs are computed and must not be configured."
    target_type  = "WORKSPACE_LEVEL"
    readme       = <<-EOT
    This building block demonstrates meshStack's MANUAL implementation type, where platform operators manually confirm execution and output values are copied directly from inputs.

    **Use cases:**
    - Manual approval workflows where a platform operator reviews and confirms a request
    - Processes that require human steps outside of automation (e.g. opening a ticket, configuring a system manually)

    **Example — Requesting Manual Access:**
    A developer requests access to a system. A platform operator reviews the request, performs the manual steps, and marks the building block as complete — the output mirrors the approved request details.

    ## Shared Responsibility

    | Responsibility | Platform Team | Application Team |
    |----------------|:-------------:|:----------------:|
    | Complete the building block run | ✅ | ❌ |
    | Provide `text`, `flag`, `num`, `single_select` inputs | ❌ | ✅ |
    | Monitor completion status | ❌ | ✅ |
    EOT
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "PURGE"
    implementation = {
      manual = {}
    }
    inputs = {
      text = {
        assignment_type = "USER_INPUT"
        display_name    = "Text"
        type            = "STRING"
      }
      flag = {
        assignment_type = "USER_INPUT"
        display_name    = "Flag"
        type            = "BOOLEAN"
      }
      num = {
        assignment_type = "USER_INPUT"
        display_name    = "Num"
        type            = "INTEGER"
      }

      # SINGLE_SELECT cannot be an output type, so the backend mirrors it to a STRING output.
      single_select = {
        assignment_type   = "USER_INPUT"
        display_name      = "Single Select"
        selectable_values = ["option1", "option2"]
        type              = "SINGLE_SELECT"
      }
      # STATIC input supplied by the building block definition (not the user); also mirrored to a STRING output.
      static_note = {
        assignment_type = "STATIC"
        display_name    = "Static Note"
        type            = "STRING"
        argument        = jsonencode("A static note value")
      }
    }

    # Outputs are omitted for manual building blocks: the backend derives one output per input
    # (assignment type NONE, with SINGLE_SELECT/MULTI_SELECT/LIST translated to output-compatible
    # types), so version_spec.outputs is computed and must not be set here.
    # Requires the meshstack provider >= 0.21.1 (see meshcloud/terraform-provider-meshstack#176).
  }
}

terraform {
  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.21.0"
    }
  }
}
