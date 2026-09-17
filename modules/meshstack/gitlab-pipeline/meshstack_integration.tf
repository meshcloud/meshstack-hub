variable "gitlab_base_url" {
  type        = string
  default     = "https://gitlab.com"
  description = "Base URL of the GitLab instance. Override for a self-hosted GitLab."
}

variable "gitlab_pipeline_trigger_token" {
  type        = string
  sensitive   = true
  description = "Pipeline trigger token for the project, created under Settings > CI/CD > Pipeline triggers. meshStack authenticates with it to start a run."
}

variable "gitlab_project_id" {
  type        = string
  description = "Numeric ID of the GitLab project holding the pipeline, as shown on the project overview page."
}

variable "gitlab_branch" {
  type        = string
  default     = "main"
  description = "Branch meshStack triggers. It must already carry ./buildingblock/gitlab-ci.yml as its .gitlab-ci.yml."
}

variable "bbd_display_name" {
  type        = string
  default     = null
  description = "Overrides the name of the marketplace entry application teams see in the catalog."
}

variable "bbd_description" {
  type        = string
  default     = null
  description = "Overrides the one-line description shown next to the marketplace entry."
}

variable "bbd_readme" {
  type        = string
  default     = null
  description = "Overrides the markdown readme shown in the marketplace before ordering."
}

variable "integration_display_name" {
  type        = string
  default     = null
  description = "Overrides the name of the meshStack integration this module registers."
}

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
  const = true
  default = {
    git_ref   = "main"
    bbd_draft = true
  }
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

resource "meshstack_integration" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
  }

  spec = {
    display_name = coalesce(var.integration_display_name, "GitLab Integration")
    config = {
      gitlab = {
        base_url = var.gitlab_base_url
      }
    }
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name = coalesce(var.bbd_display_name, "meshStack GitLab Pipeline NoOp")
    description  = coalesce(var.bbd_description, "Reference building block demonstrating meshStack's GitLab pipeline implementation type: it provisions nothing and reports every input it received back as an output.")
    target_type  = "WORKSPACE_LEVEL"
    readme = coalesce(var.bbd_readme, chomp(<<-EOT
      The **meshStack GitLab Pipeline NoOp** is a reference implementation that shows how meshStack
      drives a GitLab CI/CD pipeline as building block automation. It provisions nothing: it reports
      every input it received back to you as an output, so you can see exactly what reaches a
      pipeline and in what shape.

      ## 🎯 When to use it

      Use this building block when you want to:
      - See which input types a GitLab pipeline can receive, and how each one is encoded.
      - Check that a GitLab project, its runners and its trigger token are wired up correctly.
      - Start from a working pipeline before writing automation of your own.

      ## 💡 Usage examples

      **Example 1: Checking a new GitLab project**
      A platform engineer orders this block once after connecting a GitLab project, to confirm that
      pipelines really start and that their results make it back into meshStack.

      **Example 2: Designing a building block's inputs**
      A team about to write a GitLab-backed building block orders this one with representative
      values, then reads the outputs to see how their inputs will arrive in the pipeline.

      ## 📊 Shared Responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Maintain the GitLab project, its runners and the pipeline | ✅ | ❌ |
      | Keep the trigger token and integration valid | ✅ | ❌ |
      | Order the building block and provide inputs | ❌ | ✅ |
      | Read the outputs to understand the delivered values | ❌ | ✅ |
      EOT
    ))
  }

  version_spec = {
    draft = var.hub.bbd_draft
    # A delete run triggers the pipeline once more, so the branch below must still carry the
    # pipeline file when the building block is destroyed.
    deletion_mode = "DELETE"

    implementation = {
      gitlab_pipeline = {
        project_id      = var.gitlab_project_id
        ref_name        = var.gitlab_branch
        integration_ref = meshstack_integration.this.ref
        pipeline_trigger_token = {
          secret_value   = var.gitlab_pipeline_trigger_token
          secret_version = nonsensitive(sha256(var.gitlab_pipeline_trigger_token))
        }
      }
    }

    # Inputs reach a pipeline through two channels. `is_environment = true` sends the value as a CI
    # variable; the default sends it as a GitLab pipeline input, which only works while a matching
    # entry exists in the pipeline file's `spec:inputs` header. The three scalars below cover that
    # channel; everything that is large, structured or sensitive takes the variable channel.
    inputs = {
      text = {
        assignment_type = "USER_INPUT"
        display_name    = "Text"
        type            = "STRING"
      }
      num = {
        assignment_type = "USER_INPUT"
        display_name    = "Num"
        type            = "INTEGER"
      }
      flag = {
        assignment_type = "USER_INPUT"
        display_name    = "Flag"
        type            = "BOOLEAN"
      }

      single_select = {
        assignment_type   = "USER_INPUT"
        display_name      = "Single Select"
        type              = "SINGLE_SELECT"
        selectable_values = ["single1", "single2"]
        is_environment    = true
      }
      multi_select = {
        assignment_type   = "USER_INPUT"
        display_name      = "Multi Select"
        type              = "MULTI_SELECT"
        selectable_values = ["multi1", "multi2"]
        is_environment    = true
      }
      optional_text = {
        assignment_type = "USER_INPUT"
        display_name    = "Optional Text"
        description     = "Left unset when ordering, to show that meshStack then sends no value at all."
        type            = "STRING"
        is_optional     = true
        is_environment  = true
      }
      conditional_text = {
        assignment_type = "USER_INPUT"
        display_name    = "Conditional Text"
        description     = "Only applies while Flag is false, so a block ordered with Flag set never receives it."
        type            = "STRING"
        condition       = "input.flag == false"
        is_environment  = true
      }
      code_json = {
        assignment_type = "STATIC"
        display_name    = "Code Json"
        type            = "CODE"
        argument        = jsonencode(jsonencode({ some = "code" }))
        is_environment  = true
      }
      json_form = {
        assignment_type = "USER_INPUT"
        display_name    = "Json Form"
        description     = "Filled in through a form of its own and delivered as JSON text."
        type            = "JSON"
        json_schema = jsonencode({
          type     = "object"
          required = ["region"]
          properties = {
            region   = { type = "string", enum = ["eu-central-1", "us-east-1"] }
            replicas = { type = "integer", minimum = 1 }
          }
        })
        is_environment = true
      }
      file_yaml = {
        assignment_type = "STATIC"
        display_name    = "File Yaml"
        description     = "A file input. Nothing writes files to disk for a pipeline, so it arrives as the MIME-typed base64 blob and the pipeline decodes it itself."
        type            = "FILE"
        argument        = jsonencode("data:application/yaml;base64,c29tZTogaW5wdXQKb3RoZXI6IHZhbHVlCg==")
        is_environment  = true
      }
      sensitive_text = {
        assignment_type = "USER_INPUT"
        display_name    = "Sensitive Text"
        description     = "Only the trigger payload carries this in the clear, which is why it must take the variable channel."
        type            = "STRING"
        sensitive       = {}
        is_environment  = true
      }
      static_text = {
        assignment_type = "STATIC"
        display_name    = "Static Text"
        type            = "STRING"
        argument        = jsonencode("A static value")
        is_environment  = true
      }
      author = {
        assignment_type = "AUTHOR"
        display_name    = "Author"
        description     = "The meshStack principal that ordered this building block. Injected by meshStack, never entered by a user."
        type            = "CODE"
        is_environment  = true
      }
      user_permissions = {
        assignment_type = "USER_PERMISSIONS"
        display_name    = "User Permissions"
        type            = "CODE"
        is_environment  = true
      }
      workspace_identifier = {
        assignment_type = "WORKSPACE_IDENTIFIER"
        display_name    = "Workspace Identifier"
        type            = "STRING"
        is_environment  = true
      }
      operator_text = {
        assignment_type = "PLATFORM_OPERATOR_MANUAL_INPUT"
        display_name    = "Operator Text"
        description     = "Only a platform operator can fill this in. A block whose value is still missing parks in WAITING_FOR_OPERATOR_INPUT."
        type            = "STRING"
        is_environment  = true
      }
    }

    outputs = {
      received_from_run_object_json = {
        assignment_type = "NONE"
        display_name    = "Inputs as the run object reports them"
        type            = "CODE"
      }
      received_from_trigger_json = {
        assignment_type = "NONE"
        display_name    = "Inputs as the pipeline trigger delivered them"
        type            = "CODE"
      }
      sensitive_in_run_object_is_plaintext = {
        assignment_type = "NONE"
        display_name    = "Sensitive value readable from the API"
        type            = "BOOLEAN"
      }
      text = {
        assignment_type = "NONE"
        display_name    = "Text"
        type            = "STRING"
      }
      num = {
        assignment_type = "NONE"
        display_name    = "Num"
        type            = "INTEGER"
      }
      flag = {
        assignment_type = "NONE"
        display_name    = "Flag"
        type            = "BOOLEAN"
      }
      behavior = {
        assignment_type = "NONE"
        display_name    = "Behavior"
        type            = "STRING"
      }
      pipeline_url = {
        assignment_type = "RESOURCE_URL"
        display_name    = "Pipeline URL"
        type            = "STRING"
      }
      summary = {
        assignment_type = "SUMMARY"
        display_name    = "Summary"
        type            = "STRING"
      }
    }
  }
}

terraform {
  required_version = ">= 1.12.0"

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.25.2"
    }
  }
}
