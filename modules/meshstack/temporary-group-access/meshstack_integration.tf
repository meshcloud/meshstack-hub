variable "group_identifier" {
  type        = string
  nullable    = false
  description = "Identifier of the meshStack group every building block of this definition binds to the workspace it is ordered in, not its display name. Deploy the module once per group."
}

variable "group_display_name" {
  type        = string
  default     = null
  description = "Name of the group shown in the marketplace texts. Defaults to `group_identifier`."
}

variable "allowed_workspace_identifiers" {
  type        = list(string)
  nullable    = false
  default     = []
  description = "Workspaces that may order this building block. The definition stays visible in every workspace's marketplace, but a run in any other workspace fails before anything is bound. Empty allows every workspace."
}

variable "workspace_role_name" {
  type        = string
  nullable    = false
  default     = "Workspace Manager"
  description = "meshStack workspace role the group gets on the workspace."
}

variable "duration_days_default" {
  type        = number
  nullable    = false
  default     = 7
  description = "Default of the `Duration (Days)` input an orderer fills in."
}

variable "max_duration_days" {
  type        = number
  nullable    = false
  default     = 30
  description = "Longest duration an orderer may ask for. Keep it within the recertification maximum of the role, if it has one, or meshStack rejects the binding."
}

variable "api_key_lifetime_days" {
  type        = number
  nullable    = false
  default     = 90
  description = "How long the sweeper's API key stays valid, in days. Re-apply at least every half of it, see backplane/README.md."
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

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    tags                        = optional(map(list(string)), {})
    runner_ref = optional(object({
      kind = string
      uuid = string
    }))
  })
  description = "Shared meshStack context, see docs."
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

locals {
  group_label = coalesce(var.group_display_name, var.group_identifier)
}

module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/meshstack/temporary-group-access/backplane?ref=${var.hub.git_ref}"

  building_block_definition_uuid = meshstack_building_block_definition.this.metadata.uuid
  display_name                   = meshstack_building_block_definition.this.spec.display_name
  api_key_lifetime_days          = var.api_key_lifetime_days
  meshstack                      = var.meshstack
  hub                            = var.hub
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name = coalesce(var.bbd_display_name, "Temporary access for ${local.group_label}")
    description  = coalesce(var.bbd_description, "Gives the group ${local.group_label} the role ${var.workspace_role_name} on your workspace for a number of days, then removes it.")
    symbol       = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/meshstack/temporary-group-access/buildingblock/logo.png"
    target_type  = "WORKSPACE_LEVEL"

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
      Gives the meshStack group **${local.group_label}** the role **${var.workspace_role_name}** on your
      workspace for the number of days you choose, at most ${var.max_duration_days}. When that time is
      up, the access ends and this building block deletes itself — nobody has to remember to revoke it.

      ## 🎯 When to use it

      Order this building block when you:
      - Need ${local.group_label} to work in your workspace for a limited time, e.g. to support you or to
        review it.
      - Want the access to end on its own, without opening a second request to remove it.

      ## 💡 Usage examples

      **Example 1: Support case**
      Your team needs help debugging a deployment. You order this building block for 3 days, so the
      support group can look into your workspace and loses access once the case is closed.

      **Example 2: Audit**
      An audit of your workspace is scheduled for two weeks. You order this building block for 14 days,
      and the auditors' access ends with the audit.

      ## ⏳ How the access ends

      The access counts from the first run of the building block. On the expiry date shown in its
      summary, meshStack stops honouring the group's role, and within a day after that the building
      block is deleted, which removes the role from your workspace. To end the access early, delete
      the building block yourself.

      ## 📊 Shared Responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Decide which group and which role this building block grants | ✅ | ❌ |
      | Remove the access and delete the building block when its time is up | ✅ | ❌ |
      | Decide whether, and for how long, the group needs access | ❌ | ✅ |
      | End the access early by deleting the building block | ❌ | ✅ |
      EOT
    ))
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    runner_ref    = var.meshstack.runner_ref
    deletion_mode = "DELETE"

    implementation = {
      terraform = {
        terraform_version              = "1.12.5"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/meshstack/temporary-group-access/buildingblock"
        ref_name                       = var.hub.git_ref
        use_mesh_http_backend_fallback = true
      }
    }

    permissions = [
      "WORKSPACEPRINCIPALBINDING_LIST",
      "WORKSPACEPRINCIPALBINDING_SAVE",
      "WORKSPACEPRINCIPALBINDING_DELETE",
    ]

    inputs = {
      duration_days = {
        display_name    = "Duration (Days)"
        description     = "How many days ${local.group_label} keeps access to your workspace, at most ${var.max_duration_days}."
        type            = "INTEGER"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(var.duration_days_default)
        display_order   = 1
      }

      workspace_identifier = {
        display_name    = "Workspace Identifier"
        description     = "Workspace the group is bound to."
        type            = "STRING"
        assignment_type = "WORKSPACE_IDENTIFIER"
      }

      group_identifier = {
        display_name    = "Group Identifier"
        description     = "Identifier of the meshStack group that gets the role."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.group_identifier)
      }

      workspace_role_name = {
        display_name    = "Workspace Role"
        description     = "Workspace role the group gets."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.workspace_role_name)
      }

      max_duration_days = {
        display_name    = "Maximum Duration (Days)"
        description     = "Longest duration an orderer may ask for."
        type            = "INTEGER"
        assignment_type = "STATIC"
        argument        = jsonencode(var.max_duration_days)
      }

      allowed_workspace_identifiers = {
        display_name    = "Allowed Workspaces"
        description     = "Workspaces that may order this building block. Empty allows every workspace."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.allowed_workspace_identifiers))
      }
    }

    outputs = {
      expires_at = {
        display_name    = "Expires At"
        type            = "STRING"
        assignment_type = "NONE"
      }

      expiry_date = {
        display_name    = "Expiry Date"
        type            = "STRING"
        assignment_type = "NONE"
      }

      summary = {
        display_name    = "Summary"
        type            = "STRING"
        assignment_type = "SUMMARY"
      }
    }
  }
}

terraform {
  required_version = ">= 1.12.0"

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.28.0"
    }
  }
}
