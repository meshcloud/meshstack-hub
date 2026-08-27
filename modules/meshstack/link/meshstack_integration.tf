variable "link_display_name" {
  type        = string
  description = "Name of the marketplace entry, e.g. 'STACKIT University'. This is what application teams see in the catalog."
}

variable "link_url" {
  type        = string
  description = "Target of the link. Surfaced as the building block's resource URL."
}

variable "link_title" {
  type        = string
  default     = null
  description = "Human-readable name of the linked resource, used in the generated fallback summary. Defaults to `link_display_name`."
}

variable "link_summary" {
  type        = string
  default     = null
  description = "Markdown rendered for the application team after deployment. Defaults to a generated one-liner pointing at the URL."
}

variable "link_description" {
  type        = string
  default     = null
  description = "One-line description shown next to the marketplace entry. Defaults to a generic sentence naming the link."
}

variable "link_readme" {
  type        = string
  default     = null
  description = "Markdown readme shown in the marketplace before ordering. Defaults to a generic readme describing what ordering the link does."
}

variable "link_symbol" {
  type        = string
  default     = null
  description = "URL of the icon shown for the marketplace entry. Defaults to the meshStack logo."
}

variable "link_support_url" {
  type        = string
  default     = null
  description = "Where application teams get help with the linked resource."
}

variable "link_documentation_url" {
  type        = string
  default     = null
  description = "Documentation for the linked resource, shown alongside the marketplace entry."
}

variable "link_target_type" {
  type        = string
  default     = "WORKSPACE_LEVEL"
  description = "Whether the link is ordered per workspace or per tenant."

  validation {
    condition     = contains(["WORKSPACE_LEVEL", "TENANT_LEVEL"], var.link_target_type)
    error_message = "link_target_type must be either WORKSPACE_LEVEL or TENANT_LEVEL."
  }
}

variable "link_supported_platforms" {
  type        = list(string)
  default     = []
  description = "Platform names the marketplace entry is offered for. Leave empty for workspace-level links; required for tenant-level ones."

  validation {
    condition     = var.link_target_type == "WORKSPACE_LEVEL" || length(var.link_supported_platforms) > 0
    error_message = "link_supported_platforms must name at least one platform when link_target_type is TENANT_LEVEL."
  }
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
  `git_ref`: Hub release reference. Set to a tag (e.g. 'v1.2.3') or branch or commit sha of meshcloud/meshstack-hub repo.
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
  title = coalesce(var.link_title, var.link_display_name)

  default_readme = chomp(<<-EOT
    Ordering this building block publishes a link to ${local.title} in your workspace. It
    provisions no infrastructure — it puts the address, and a short description of what waits
    behind it, where your team already works instead of in a bookmark or a wiki page.

    ## 🎯 When to use it

    Use this building block when you:
    - Want ${local.title} to be discoverable from meshPanel by everyone on the team.
    - Prefer ordering access through the marketplace over passing a URL around.

    ## 💡 Usage examples

    **Example 1: Onboarding a new team member**
    A developer joining the workspace opens meshPanel, finds ${local.title} already listed, and
    follows the link without having to ask anyone where it lives.

    ## 📊 Shared Responsibility

    | Responsibility | Platform Team | Application Team |
    |---|:---:|:---:|
    | Offer the link and keep its address current | ✅ | ❌ |
    | Operate the linked service and its content | ❌ | ❌ |
    | Use the linked resource | ❌ | ✅ |
    EOT
  )
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name = var.link_display_name
    symbol = coalesce(
      var.link_symbol,
      "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/meshstack/link/buildingblock/logo.png"
    )
    description       = coalesce(var.link_description, "Provides a link to ${local.title}. Provisions no infrastructure.")
    readme            = coalesce(var.link_readme, local.default_readme)
    target_type       = var.link_target_type
    run_transparency  = true
    support_url       = var.link_support_url
    documentation_url = var.link_documentation_url
    # meshStack requires null rather than an empty set for workspace-level definitions.
    supported_platforms = length(var.link_supported_platforms) > 0 ? [for name in var.link_supported_platforms : { name = name }] : null
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"

    implementation = {
      terraform = {
        terraform_version              = "1.12.5"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/meshstack/link/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      url = {
        display_name    = "URL"
        description     = "Target of the link."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.link_url)
      }

      title = {
        display_name    = "Title"
        description     = "Human-readable name of the linked resource."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(local.title)
      }

      # STRING rather than CODE: the value reaches the building block as a plain markdown string,
      # with no parsing step that a document full of pipes and backticks could trip over.
      summary = {
        display_name    = "Summary"
        description     = "Markdown rendered for the application team after deployment."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.link_summary != null ? var.link_summary : "")
      }
    }

    outputs = {
      url = {
        display_name    = var.link_display_name
        type            = "STRING"
        assignment_type = "RESOURCE_URL"
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
      version = ">= 0.21.0"
    }
  }
}
