variable "hub" {
  type = object({
    git_ref   = optional(string, "main")
    bbd_draft = optional(bool, false)
  })
  default     = {}
  description = <<-EOT
  `git_ref`: Hub release reference. Set to a tag (e.g. 'v1.2.3') or branch or commit sha of the meshstack-hub repo.
  `bbd_draft`: If true, the building block definition version is kept in draft mode.
  EOT
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    tags                        = optional(map(list(string)), {})
  })
  description = "Shared meshStack context. Tags are optional and propagated to building block definition metadata."
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name = "meshStack NoOp Building Block"
    description  = "Reference building block demonstrating meshStack's complete Terraform interface: all input types, file inputs, user permissions injection, and pre-run scripts."
    target_type  = "WORKSPACE_LEVEL"
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "PURGE"
    implementation = {
      terraform = {
        ref_name          = var.hub.git_ref
        repository_path   = "modules/meshstack/noop/buildingblock"
        repository_url    = "https://github.com/meshcloud/meshstack-hub.git"
        terraform_version = "1.11.0"
        pre_run_script    = file("${path.module}/buildingblock/prerun.sh")
      }
    }
    inputs = {
      flag = {
        assignment_type = "USER_INPUT"
        display_name    = "Flag"
        type            = "BOOLEAN"
      }
      multi_select = {
        assignment_type   = "USER_INPUT"
        display_name      = "Multi Select"
        selectable_values = ["multi1", "multi2"]
        type              = "MULTI_SELECT"
      }
      multi_select_json = {
        assignment_type   = "USER_INPUT"
        display_name      = "Multi Select Json"
        selectable_values = ["multi1", "multi2"]
        type              = "MULTI_SELECT"
      }
      num = {
        assignment_type = "USER_INPUT"
        display_name    = "Num"
        type            = "INTEGER"
      }

      "sensitive-file.yaml" = {
        assignment_type = "STATIC"
        display_name    = "Sensitive File.yaml"
        type            = "FILE"
        sensitive = {
          argument = {
            secret_value   = "data:application/yaml;base64,c29tZTogaW5wdXQKb3RoZXI6IHZhbHVlCg=="
            secret_version = null
          }
        }
      }
      sensitive_text = {
        assignment_type = "USER_INPUT"
        display_name    = "Sensitive Text"
        type            = "STRING"
        sensitive       = {}
      }
      sensitive_yaml = {
        assignment_type = "STATIC"
        display_name    = "Sensitive Yaml"
        type            = "CODE"
        sensitive = {
          argument = {
            secret_value = "some: yaml\nother: value\n"
          }
        }
      }
      single_select = {
        assignment_type   = "USER_INPUT"
        display_name      = "Single Select"
        selectable_values = ["single1", "single2"]
        type              = "SINGLE_SELECT"
      }
      "some-file.yaml" = {
        assignment_type = "STATIC"
        display_name    = "Yaml"
        type            = "FILE"
        argument        = jsonencode("data:application/yaml;base64,c29tZTogaW5wdXQKb3RoZXI6IHZhbHVlCg==")
      }
      static = {
        argument        = jsonencode("A static value")
        assignment_type = "STATIC"
        display_name    = "Static"
        type            = "STRING"
      }
      static_code = {
        argument        = jsonencode(jsonencode({ some : "code" }))
        assignment_type = "STATIC"
        display_name    = "Static Code"
        type            = "CODE"
      }
      text = {
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("")
        display_name    = "Text"
        type            = "STRING"
      }
      user_permissions = {
        assignment_type = "USER_PERMISSIONS"
        display_name    = "User Permissions"
        type            = "CODE"
      }
      user_permissions_json = {
        assignment_type = "USER_PERMISSIONS"
        display_name    = "User Permissions"
        type            = "CODE"
      }
    }
    outputs = {
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
      text = {
        assignment_type = "NONE"
        display_name    = "Text"
        type            = "STRING"
      }
      static_code = {
        assignment_type = "NONE"
        display_name    = "Static Code"
        type            = "CODE"
      }
      resource_url = {
        assignment_type = "RESOURCE_URL"
        display_name    = "Resource URL"
        type            = "STRING"
      }
      summary = {
        assignment_type = "SUMMARY"
        display_name    = "Summary"
        type            = "STRING"
      }
      debug_input_variables_json = {
        assignment_type = "NONE"
        display_name    = "Input Variables as JSON for debugging"
        type            = "CODE"
      }
      debug_input_files_json = {
        assignment_type = "NONE"
        display_name    = "Input Files as JSON for debugging"
        type            = "CODE"
      }
    }
  }
}

output "building_block_definition_uuid" {
  value = meshstack_building_block_definition.this.metadata.uuid
}

output "building_block_definition_version_uuid" {
  description = "UUID of the latest version. In draft mode returns the latest draft; otherwise returns the latest release."
  value       = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest.uuid : meshstack_building_block_definition.this.version_latest_release.uuid
}

terraform {
  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.19.3"
    }
  }
}
