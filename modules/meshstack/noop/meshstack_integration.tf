variable "runner_ref" {
  type = object({
    kind = string
    uuid = string
  })
  default     = null
  description = "Optional reference to a meshStack building block runner. When set, building block runs are dispatched to this custom runner. Obtain the value from the backplane module's `runner_ref` output."
}

variable "tenant_tag_inputs" {
  type = object({
    project_tag_key        = string
    payment_method_tag_key = string
    landing_zone_tag_key   = string
    platform_type_name     = string
  })
  default     = null
  description = <<-EOT
  When set, a second, tenant-level definition is published whose inputs read these three meshStack
  tags. Tag keys are named rather than discovered, because a definition stores only the key and
  meshStack resolves the value per building block. `platform_type_name` names the meshPlatformType
  the definition supports, which meshStack requires of every tenant-level definition.
  EOT
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
    git_ref     = var.hub.git_ref
  }
}

output "tenant_building_block_definition" {
  description = "Tenant-level BBD reading meshStack tags. Null unless `tenant_tag_inputs` is set."
  value = var.tenant_tag_inputs == null ? null : {
    uuid        = one(meshstack_building_block_definition.tenant_tag_inputs).metadata.uuid
    version_ref = var.hub.bbd_draft ? one(meshstack_building_block_definition.tenant_tag_inputs).version_latest : one(meshstack_building_block_definition.tenant_tag_inputs).version_latest_release
    git_ref     = var.hub.git_ref
  }
}

locals {
  # Both definitions run the same building block, whose variables have no defaults, so each one has
  # to declare every input. Sharing them keeps the two from drifting apart.
  noop_inputs = {
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
    optional_text = {
      assignment_type = "USER_INPUT"
      display_name    = "Optional Text"
      type            = "STRING"
      is_optional     = true
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

  noop_outputs = {
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
    optional_text = {
      assignment_type = "NONE"
      display_name    = "Optional Text"
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

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name = "meshStack NoOp Building Block"
    description  = "Reference building block demonstrating meshStack's complete Terraform interface: all input types, file inputs, user permissions injection, and pre-run scripts."
    target_type  = "WORKSPACE_LEVEL"
    readme = chomp(<<-EOT
      The **meshStack NoOp Building Block** is a reference implementation that demonstrates meshStack's
      complete Terraform building block interface without provisioning any real infrastructure. It covers
      all input types, file inputs, user permissions injection, and pre-run scripts.

      ## 🎯 When to use it

      Use this building block when you want to:
      - Understand the full range of input types available in meshStack building blocks.
      - Test the building block framework without side effects.
      - Use it as a starting point or template for building new building blocks.

      ## 💡 Usage examples

      **Example 1: Exploring input types**
      Platform engineers can deploy this building block to a test workspace to see how all input
      types (text, number, select, file, sensitive) are surfaced in the meshStack UI and passed
      to Terraform.

      **Example 2: Onboarding new module developers**
      A new platform engineer reviews the NoOp building block to learn the conventions before
      writing their first real building block module.

      ## 📊 Shared Responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Maintain the NoOp reference implementation | ✅ | ❌ |
      | Deploy and test the building block | ❌ | ✅ |
      EOT
    )
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"
    runner_ref    = var.runner_ref
    implementation = {
      terraform = {
        ref_name          = var.hub.git_ref
        repository_path   = "modules/meshstack/noop/buildingblock"
        repository_url    = "https://github.com/meshcloud/meshstack-hub.git"
        terraform_version = "1.12.5"
        pre_run_script    = file("${path.module}/buildingblock/prerun.sh")
      }
    }
    inputs  = local.noop_inputs
    outputs = local.noop_outputs
  }
}

# Only a tenant-level building block has a project, a payment method and a landing zone to read tags
# from — a workspace-level one can reach workspace tags and nothing else. So the TAG inputs need a
# definition of their own. It runs the same building block; the three inputs are the only difference.
resource "meshstack_building_block_definition" "tenant_tag_inputs" {
  count = var.tenant_tag_inputs == null ? 0 : 1

  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name        = "meshStack NoOp Tenant Building Block"
    description         = "Tenant-level reference building block demonstrating inputs resolved from meshStack tags."
    target_type         = "TENANT_LEVEL"
    supported_platforms = [{ name = var.tenant_tag_inputs.platform_type_name }]
    readme = chomp(<<-EOT
      The **meshStack NoOp Tenant Building Block** shows how a building block reads metadata meshStack
      already governs. Three of its inputs are sourced from tags — on your project, on the payment
      method funding it, and on your tenant's landing zone — so nobody has to type a cost center or an
      environment classification into a form twice.

      Everything else it does matches the workspace-level NoOp building block: it provisions no real
      infrastructure and reports every input it received back as an output.

      ## 🎯 When to use it

      Use this building block when you want to:
      - See which tags a tenant-level building block can read, and what their values look like.
      - Check that your tag schema reaches your building blocks before you depend on it.
      - Confirm that editing a tag makes meshStack re-run the building blocks that read it.

      ## 💡 Usage examples

      **Example 1: Checking a cost center reaches your tooling**
      Set the cost center tag on your project, deploy this building block, and read the resolved value
      from its outputs — no need to instrument a real building block first.

      **Example 2: Watching a tag change take effect**
      Change the tag value and watch meshStack start a new run on its own. The outputs then carry the
      new value, which is what a real building block would act on.

      ## 📊 Shared Responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Define the tag schema and which tags this building block reads | ✅ | ❌ |
      | Set the tag values on the workspace, project and payment method | ❌ | ✅ |
      | Deploy and test the building block | ❌ | ✅ |
      EOT
    )
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"
    runner_ref    = var.runner_ref
    implementation = {
      terraform = {
        ref_name          = var.hub.git_ref
        repository_path   = "modules/meshstack/noop/buildingblock"
        repository_url    = "https://github.com/meshcloud/meshstack-hub.git"
        terraform_version = "1.12.5"
        pre_run_script    = file("${path.module}/buildingblock/prerun.sh")
      }
    }
    # A TAG input is always CODE and never sensitive — a tag value is a list of strings, and tags are
    # visible metadata. The provider rejects both mistakes at plan time.
    inputs = merge(local.noop_inputs, {
      project_tag = {
        assignment_type = "TAG"
        display_name    = "Project Tag"
        type            = "CODE"
        argument        = jsonencode("PROJECT.${var.tenant_tag_inputs.project_tag_key}")
      }
      payment_method_tag = {
        assignment_type = "TAG"
        display_name    = "Payment Method Tag"
        type            = "CODE"
        argument        = jsonencode("PAYMENT_METHOD.${var.tenant_tag_inputs.payment_method_tag_key}")
      }
      landing_zone_tag = {
        assignment_type = "TAG"
        display_name    = "Landing Zone Tag"
        type            = "CODE"
        argument        = jsonencode("LANDING_ZONE.${var.tenant_tag_inputs.landing_zone_tag_key}")
      }
    })
    outputs = local.noop_outputs
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
