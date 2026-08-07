variable "link_url" {
  type        = string
  default     = "https://docs.meshcloud.io"
  description = "Target of the link the created building block publishes. The created definition runs the hub's `link` building block, which provisions nothing but this address."
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

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name = "meshStack Composition Building Block"
    description  = "Reference building block demonstrating the composition pattern: creates a link building block definition and a building block from it using the run's ephemeral API key."
    target_type  = "WORKSPACE_LEVEL"
    symbol       = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/meshstack/composition/buildingblock/logo.png"

    # Lets consuming workspace users read the run logs, which is where the interesting part happens.
    run_transparency = true

    readme = chomp(<<-EOT
    Creates a link building block definition in your workspace and a building block from it. Both
    carry a "created by building block" reference back to this building block, so you can follow
    where they came from. Nothing is provisioned outside meshStack, and no step needs an operator.

    ## 🎯 When to use it

    Use this building block when you:
    - Want to see the composition pattern end to end — a building block provisioning meshObjects
      through the meshStack API rather than cloud resources.
    - Need a self-service way to hand a workspace its own building block definition without a
      platform engineer creating one by hand.

    ## 💡 Usage examples

    **Example 1: Exploring compositions**
    A developer adds this building block to a sandbox workspace and inspects the definition and
    building block that appear, following the creator link on each back to this building block.

    **Example 2: Offering a workspace its own marketplace link**
    A team wants a documentation link published in their own workspace's marketplace and gets both
    the definition and a ready-made building block by adding this building block.

    ## 📊 Shared Responsibility

    | Responsibility | Platform Team | Application Team |
    |---|:---:|:---:|
    | Maintain this composition and its permissions | ✅ | ❌ |
    | Operate whatever the published link points at | ❌ | ❌ |
    | Choose the name and link target | ❌ | ✅ |
    | Decide when to add or remove this building block | ❌ | ✅ |
    EOT
    )
  }

  version_spec = {
    draft = var.hub.bbd_draft

    # DELETE so removing the building block runs `tofu destroy` and cleans up what it created.
    deletion_mode = "DELETE"

    implementation = {
      terraform = {
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/meshstack/composition/buildingblock"
        ref_name                       = var.hub.git_ref
        terraform_version              = "1.11.0"
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      name = {
        assignment_type = "USER_INPUT"
        type            = "STRING"
        display_name    = "Name"
        description     = "Name given to the building block definition and building block this composition creates."
        default_value   = jsonencode("Composition Demo")
      }
      link_url = {
        assignment_type = "USER_INPUT"
        type            = "STRING"
        display_name    = "Link URL"
        description     = "Target of the link the created building block publishes."
        default_value   = jsonencode(var.link_url)
      }
      workspace_identifier = {
        assignment_type = "WORKSPACE_IDENTIFIER"
        type            = "STRING"
        display_name    = "Workspace Identifier"
        description     = "Workspace the created meshObjects belong to. Always the consuming workspace, which is the one the run's ephemeral API key is scoped to."
      }
      # Pins the created definition's implementation to the same hub revision as this one.
      hub_git_ref = {
        assignment_type = "STATIC"
        type            = "STRING"
        display_name    = "Hub Git Ref"
        argument        = jsonencode(var.hub.git_ref)
      }
    }

    outputs = {
      created_building_block_definition_uuid = {
        assignment_type = "NONE"
        type            = "STRING"
        display_name    = "Created Building Block Definition"
      }
      created_building_block_uuid = {
        assignment_type = "NONE"
        type            = "STRING"
        display_name    = "Created Building Block"
      }
      summary = {
        assignment_type = "SUMMARY"
        type            = "STRING"
        display_name    = "Summary"
      }
    }

    # Grants each run an ephemeral API key with exactly these workspace permissions. Creating the
    # meshObjects with that key is what records this building block as their creator.
    permissions = [
      "BUILDINGBLOCKDEFINITION_LIST",
      "BUILDINGBLOCKDEFINITION_SAVE",
      "BUILDINGBLOCKDEFINITION_DELETE",
      "BUILDINGBLOCK_LIST",
      "BUILDINGBLOCK_SAVE",
      "BUILDINGBLOCK_DELETE",
    ]
  }
}

terraform {
  required_version = ">= 1.12.0"

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.24.0"
    }
  }
}
