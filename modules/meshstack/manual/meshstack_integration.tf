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
    description  = "Reference building block demonstrating the MANUAL implementation type: outputs mirror selected inputs 1:1, with extra inputs (SINGLE_SELECT and STATIC) that have no corresponding output."
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
    | Provide `text`, `flag`, `num`, inputs | ❌ | ✅ |
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

      # TODO: these two currently break the terraform provider because they can't be mapped to an output type
      # This is a known issue that needs to be fixed in meshStack
      # > produced an unexpected new value:
      #  .version_spec.outputs: new element "single_select" has appeared.
      #  .version_spec.outputs: new element "static_note" has appeared.

      # single_select = {
      #   assignment_type   = "USER_INPUT"
      #   display_name      = "Single Select"
      #   selectable_values = ["option1", "option2"]
      #   type              = "SINGLE_SELECT"
      # }
      # # Static input with no corresponding output — exercises more-inputs-than-outputs
      # static_note = {
      #   assignment_type = "STATIC"
      #   display_name    = "Static Note"
      #   type            = "STRING"
      #   argument        = jsonencode("A static note value")
      # }
    }
    # Output keys must match input keys; types must be compatible with manual mirroring.
    # Only text, flag, and num are output — single_select and static_note are intentionally omitted.
    outputs = {
      text = {
        assignment_type = "NONE"
        display_name    = "Text"
        type            = "STRING"
      }
      flag = {
        assignment_type = "NONE"
        display_name    = "Flag"
        type            = "BOOLEAN"
      }
      num = {
        assignment_type = "NONE"
        display_name    = "Num"
        type            = "INTEGER"
      }
    }
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
