variable "azure_tenant_id" {
  type        = string
  description = "Azure Entra tenant ID where groups will be created."
}

variable "azure_location" {
  type        = string
  description = "Azure region for the backplane resource group and UAMI (e.g. 'westeurope')."
}

variable "azure_user_lookup_attribute" {
  type        = string
  default     = "email"
  description = "Directory attribute used to match meshStack project members to Entra users. 'email' matches the user's SMTP address (the portal's Email field) and is the right choice when members are B2B guests, whose user principal name is rewritten on invitation. 'upn' matches the user principal name and only works for members native to this tenant."

  validation {
    condition     = contains(["upn", "email"], var.azure_user_lookup_attribute)
    error_message = "Must be 'upn' or 'email'."
  }
}

variable "target_type" {
  type        = string
  default     = "TENANT_LEVEL"
  description = "'TENANT_LEVEL' creates one group per project role for an Azure tenant. 'WORKSPACE_LEVEL' creates one group per workspace holding every workspace member, whatever their workspace role. Set `groups` to create other groups instead."

  validation {
    condition     = contains(["TENANT_LEVEL", "WORKSPACE_LEVEL"], var.target_type)
    error_message = "Must be 'TENANT_LEVEL' or 'WORKSPACE_LEVEL'."
  }
}

variable "groups" {
  type = map(object({
    name  = string
    roles = optional(list(string))
  }))
  default     = null
  description = <<-EOT
  The groups each building block creates, keyed by a stable key. Null keeps the default layout described for `target_type`.
  `name`: Group display name. `{workspace}` and `{project}` are replaced by the identifiers of the building block's workspace and project, e.g. '{workspace}.cldy-finops.admin'.
  `roles`: Only members holding one of these roles join the group. Workspace roles are 'Workspace Owner', 'Workspace Manager' and 'Workspace Member'; project roles are role identifiers such as 'admin'. Null adds every member.
  Changing a key deletes the group and creates a new one with another object ID, so keep keys stable and change `name` to rename a group.
  EOT

  validation {
    condition     = var.groups == null || alltrue([for group in values(var.groups) : strcontains(group.name, "{workspace}")])
    error_message = "Every group name must contain '{workspace}', otherwise the building blocks of all workspaces create groups with the same name."
  }

  validation {
    condition     = var.groups == null || length(distinct([for group in values(var.groups) : group.name])) == length(var.groups)
    error_message = "Every group needs its own name."
  }

  validation {
    condition     = var.groups == null || alltrue([for group in values(var.groups) : group.roles == null || length(group.roles) > 0])
    error_message = "Set roles to null to add every member. An empty list would leave the group empty."
  }
}

variable "backplane_name" {
  type        = string
  default     = "azure-entra-id-groups"
  description = "Name for the backplane resources (resource group, UAMI). Must match pattern ^[-a-z0-9]+$."

  validation {
    condition     = can(regex("^[-a-z0-9]+$", var.backplane_name))
    error_message = "Only lowercase alphanumeric characters and dashes are allowed."
  }
}

variable "notification_subscribers" {
  type        = list(string)
  default     = []
  description = "Email addresses notified on building block lifecycle events."
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
    additional_trusted_runner_refs = optional(list(object({
      kind = string
      uuid = string
    })), [])
    supported_platforms = optional(list(object({
      kind = optional(string)
      name = optional(string)
      uuid = optional(string)
    })), [{ name = "AZURE" }])
  })
  description = "Shared meshStack context, see docs."
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

# Lookup specified runner for workload identity federation info. Null results in the default hosted runner.
module "runner" {
  source = "github.com/meshcloud/meshstack-hub//modules/meshstack/runner-identity?ref=${var.hub.git_ref}"

  cloud                          = "azure"
  runner_ref                     = var.meshstack.runner_ref
  additional_trusted_runner_refs = var.meshstack.additional_trusted_runner_refs
  versions                       = meshstack_building_block_definition.this.versions
}

output "building_block_definition" {
  description = "BBD is consumed in building block compositions."
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  }
}

module "backplane" {
  source   = "github.com/meshcloud/meshstack-hub//modules/azure/entra-id-groups/backplane?ref=${var.hub.git_ref}"
  name     = var.backplane_name
  location = var.azure_location

  workload_identity_federation = {
    issuer   = module.runner.issuer
    audience = module.runner.audience
    subjects = [meshstack_building_block_definition.this.version_latest.workload_identity_federation.subject]
  }

  trusted_runner_identities = module.runner.trusted_identities
}

locals {
  workspace_level   = var.target_type == "WORKSPACE_LEVEL"
  custom_groups     = var.groups != null
  configured_groups = var.groups == null ? {} : var.groups
  scope             = local.workspace_level ? "workspace" : "project"
  workspace_roles   = ["Workspace Owner", "Workspace Manager", "Workspace Member"]

  offers_input = {
    prefix             = !local.custom_groups
    groups             = local.custom_groups
    project_identifier = !local.workspace_level
    project_roles      = !local.workspace_level && !local.custom_groups
  }

  display_name = local.workspace_level ? (local.custom_groups ? "Azure Entra ID Workspace Groups" : "Azure Entra ID Workspace Group") : "Azure Entra ID Groups"
  description = (
    local.custom_groups ? "Creates the Entra security groups your platform team defined for a meshStack ${local.scope}, each holding the members with the roles it names." :
    local.workspace_level ? "Creates an Entra security group holding every member of a meshStack workspace, with optional Administrative Unit membership." :
    "Creates Entra security groups for meshStack project roles, with optional Administrative Unit membership."
  )

  custom_groups_readme = {
    intro = "Automatically provision the Entra ID security groups your platform team defined for a meshStack ${local.scope}, and keep each group in sync with the ${local.scope} members that hold its roles."
    use_cases = join("\n", [
      "- Give each purpose its own group, such as FinOps or service administration, so access granted to it in Azure follows the ${local.scope} roles in meshStack.",
      "- Keep that access in sync with meshStack: when someone joins, leaves or changes their role in the ${local.scope}, the groups follow on the next run.",
      "- Optionally scope the groups inside a dedicated Entra Administrative Unit to isolate them from the rest of the directory.",
    ])
    examples = join("\n", concat(
      [
        "**Groups your platform team defined:**",
        "",
        local.workspace_level ? "Workspace `my-workspace` gets these groups:" : "Project `my-project` in workspace `my-workspace` gets these groups:",
        "",
        "| Entra group | Members |",
        "|---|---|",
      ],
      [
        for group in values(local.configured_groups) :
        "| `${replace(replace(group.name, "{workspace}", "my-workspace"), "{project}", "my-project")}` | ${group.roles == null ? "Every ${local.scope} member" : join(", ", group.roles)} |"
      ]
    ))
    responsibilities = join("\n", [
      "| Choose which groups exist and which roles join them | ✅ | ❌ |",
      "| Add users to the generated groups (automated via ${local.scope} membership) | ✅ | ❌ |",
      "| Manage who holds which ${local.scope} role | ❌ | ✅ |",
    ])
  }

  # Lines joined rather than %{if} directives in the readme heredoc: a directive line keeps its
  # source indentation and leaves blank lines behind, which breaks the lists and the table.
  readme_variant = local.custom_groups ? local.custom_groups_readme : local.workspace_level ? {
    intro = "Automatically provision one Entra ID security group for a meshStack workspace and keep every workspace member in it. The group is named after the workspace identifier with an optional prefix, so access granted to it in Azure follows workspace membership in meshStack."
    use_cases = join("\n", [
      "- Grant a whole team access to Azure resources, such as a subscription or a shared service, through one group instead of user by user.",
      "- Keep that access in sync with meshStack: someone who joins or leaves the workspace joins or leaves the group on the next run.",
      "- Optionally scope the group inside a dedicated Entra Administrative Unit to isolate it from the rest of the directory.",
    ])
    examples = join("\n", [
      "**Default:**",
      "",
      "Workspace `my-workspace` with prefix `plat` produces the group `plat.my-workspace`. Every Workspace Owner, Workspace Manager and Workspace Member is a member of it.",
    ])
    responsibilities = join("\n", [
      "| Add users to the generated group (automated via workspace membership) | ✅ | ❌ |",
      "| Manage who is a member of the workspace | ❌ | ✅ |",
    ])
    } : {
    intro = "Automatically provision Entra ID security groups for every role in a meshStack project. Groups are named consistently using the workspace identifier, project identifier, an optional prefix, and the role name as suffix — giving your teams a predictable, auditable group structure in Azure Active Directory."
    use_cases = join("\n", [
      "- Map meshStack project roles (admin, user, reader, or custom roles) to Entra security groups for RBAC assignments in Azure.",
      "- Enforce a standard naming scheme across all projects in your platform.",
      "- Optionally scope groups inside a dedicated Entra Administrative Unit to isolate tenant-level identities from the rest of the directory.",
    ])
    examples = join("\n", [
      "**Default meshStack roles (admin / user / reader):**",
      "",
      "A project `my-project` in workspace `my-workspace` with prefix `plat` produces three groups:",
      "- `plat.my-workspace.my-project.admin`",
      "- `plat.my-workspace.my-project.user`",
      "- `plat.my-workspace.my-project.reader`",
      "",
      "**Custom roles:**",
      "",
      "Set *Project Roles* to `devops,qa,readonly` to create:",
      "- `plat.my-workspace.my-project.devops`",
      "- `plat.my-workspace.my-project.qa`",
      "- `plat.my-workspace.my-project.readonly`",
    ])
    responsibilities = join("\n", [
      "| Choose which project roles get groups | ❌ | ✅ |",
      "| Assign users to generated groups (automated via project membership) | ✅ | ❌ |",
      "| Manage which users have which project roles | ❌ | ✅ |",
    ])
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name             = coalesce(var.bbd_display_name, local.display_name)
    description              = coalesce(var.bbd_description, local.description)
    support_url              = "mailto:support@meshcloud.io"
    documentation_url        = "https://hub.meshcloud.io/platforms/azure/definitions/azure-entra-id-groups"
    notification_subscribers = var.notification_subscribers
    symbol                   = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/main/modules/azure/entra-id-groups/buildingblock/logo.png"
    target_type              = var.target_type
    supported_platforms      = local.workspace_level ? null : [{ name = "AZURE" }]

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
      ${local.readme_variant.intro}

      ## When to use it

      Use this building block when you want to:
      ${local.readme_variant.use_cases}

      ## Usage examples

      ${local.readme_variant.examples}

      **With Administrative Unit:**

      Provide the object ID of an existing Entra Administrative Unit. All generated groups are added as members of that AU, restricting who can manage them in the directory.

      ## Members that cannot be resolved

      Members are matched to directory users by the attribute your platform team configured — the SMTP address by default. A member with no object in the directory, such as an external collaborator or a service account, is skipped rather than failing the deployment: the groups are still created and every other member is still assigned. The run summary names anyone who was skipped, and the *Unresolved Members* output lists them so you can act on it.

      Such a member keeps their meshStack roles, but they will not inherit any access granted through these groups until they exist in the directory.

      ## Shared Responsibilities

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Deploy and configure the backplane identity | ✅ | ❌ |
      | Define the group naming convention | ✅ | ❌ |
      | Create and delete Entra groups | ✅ | ❌ |
      | Add the Administrative Unit (optional) | ✅ | ❌ |
      ${local.readme_variant.responsibilities}
      | Use group IDs in downstream RBAC assignments | ❌ | ✅ |
    EOT
    ))
  }

  version_spec = {
    draft = var.hub.bbd_draft

    deletion_mode = "DELETE"
    runner_ref    = module.runner.ref

    implementation = {
      terraform = {
        terraform_version              = "1.12.5"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/azure/entra-id-groups/buildingblock"
        ref_name                       = var.hub.git_ref
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = merge({
      ARM_CLIENT_ID = {
        type            = "STRING"
        display_name    = "ARM Client ID"
        description     = "Client ID of the UAMI used to authenticate with Azure."
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(module.backplane.identity.client_id)
      }
      ARM_TENANT_ID = {
        type            = "STRING"
        display_name    = "ARM Tenant ID"
        description     = "Azure Entra tenant ID for authentication."
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(var.azure_tenant_id)
      }
      ARM_USE_OIDC = {
        type            = "STRING"
        display_name    = "ARM Use OIDC"
        description     = "Enables OIDC-based workload identity federation for the AzureAD provider."
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode("true")
      }
      ARM_OIDC_TOKEN_FILE_PATH = {
        type            = "STRING"
        display_name    = "ARM OIDC Token File Path"
        description     = "Path to the OIDC token file used for workload identity federation."
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(module.runner.token_path)
      }
      workspace_identifier = {
        type            = "STRING"
        display_name    = "Workspace Identifier"
        description     = "meshStack workspace identifier. Injected automatically from the platform context."
        assignment_type = "WORKSPACE_IDENTIFIER"
      }
      administrative_unit_id = {
        type            = "STRING"
        display_name    = "Administrative Unit ID"
        description     = "Object ID of the Entra Administrative Unit to add the groups to. Leave empty to skip AU membership."
        assignment_type = "USER_INPUT"
        is_optional     = true
      }
      user_lookup_attribute = {
        type            = "STRING"
        display_name    = "User Lookup Attribute"
        description     = "Directory attribute used to look up users. 'email' matches the SMTP address; 'upn' matches the User Principal Name."
        assignment_type = "STATIC"
        argument        = jsonencode(var.azure_user_lookup_attribute)
      }
      users = {
        type            = "CODE"
        display_name    = "Users"
        description     = "Project or workspace members from meshStack with their assigned roles. Injected automatically by meshStack."
        assignment_type = "USER_PERMISSIONS"
      }
      }, { for k, v in {
        prefix = {
          type            = "STRING"
          display_name    = "Group Name Prefix"
          description     = "Optional prefix prepended to all group display names (e.g. 'plat'). Leave empty to omit."
          assignment_type = "USER_INPUT"
          is_optional     = true
        }
        groups = {
          type            = "CODE"
          display_name    = "Groups"
          description     = "The groups to create and the roles whose members join each of them, as defined by the platform team."
          assignment_type = "STATIC"
          argument        = jsonencode(var.groups)
        }
        project_identifier = {
          type            = "STRING"
          display_name    = "Project Identifier"
          description     = "meshStack project identifier. Injected automatically from the platform context."
          assignment_type = "PROJECT_IDENTIFIER"
        }
        project_roles = {
          type            = "STRING"
          display_name    = "Project Roles"
          description     = "Comma-separated list of project role name suffixes. One Entra group is created per role. Defaults to the three standard meshStack roles."
          assignment_type = "USER_INPUT"
          default_value   = jsonencode("admin,user,reader")
        }
    } : k => v if local.offers_input[k] })

    outputs = {
      group_object_ids = {
        type            = "STRING"
        display_name    = "Group Object IDs"
        description     = "JSON map of group key to Entra group object ID. Without configured groups, the key is the project role name."
        assignment_type = "NONE"
      }
      group_display_names = {
        type            = "STRING"
        display_name    = "Group Display Names"
        description     = "JSON map of group key to Entra group display name. Without configured groups, the key is the project role name."
        assignment_type = "NONE"
      }
      unresolved_users = {
        type            = "STRING"
        display_name    = "Unresolved Members"
        description     = "Project members with no matching object in the directory. They keep their meshStack project roles but were not added to any group."
        assignment_type = "NONE"
      }
      summary = {
        type            = "STRING"
        display_name    = "Summary"
        description     = "Markdown summary of the created groups, and a warning naming any members that could not be resolved."
        assignment_type = "SUMMARY"
      }
    }
  }

  lifecycle {
    precondition {
      condition = alltrue([
        for group in values(local.configured_groups) : strcontains(group.name, "{project}") == !local.workspace_level
      ])
      error_message = "With target_type TENANT_LEVEL every group name must contain '{project}'. With WORKSPACE_LEVEL no group name may contain it, because a workspace building block has no project."
    }

    precondition {
      condition = !local.workspace_level || alltrue([
        for group in values(local.configured_groups) : group.roles == null || length(setsubtract(group.roles, local.workspace_roles)) == 0
      ])
      error_message = "With target_type WORKSPACE_LEVEL, group roles must be among ${join(", ", local.workspace_roles)}."
    }
  }
}

terraform {
  required_version = ">= 1.12.0"

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.27.2"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0, < 5.0.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 3.8, < 4.0.0"
    }
  }
}
