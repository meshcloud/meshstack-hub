variable "test_context" {
  type = object({
    hub_git_ref = string
    workspace   = string
    name_suffix = string

    # Mode discriminator: set in foundation mode to order an already-deployed BBD version;
    # null in build-from-source mode, which builds the BBD from hub source.
    bbd_version_ref = optional(object({
      uuid = string
    }))
  })
  nullable = false
}

locals {
  link_url   = "https://docs.meshcloud.io/"
  link_title = "meshStack Documentation"

  # Pipes, backticks and a table on purpose: the summary travels to the building block as a STRING
  # input rather than CODE precisely so markdown like this survives the trip unparsed.
  link_summary = chomp(<<-EOT
    # ${local.link_title}

    | Resource | Address |
    |---|---|
    | Docs | `${local.link_url}` |

    [Open ${local.link_title}](${local.link_url})
    EOT
  )
}

module "meshstack_link" {
  count  = var.test_context.bbd_version_ref == null ? 1 : 0
  source = "../"

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }

  link_display_name = "Smoke Test Link"
  link_url          = local.link_url
  link_title        = local.link_title
  link_summary      = local.link_summary
}

locals {
  version_ref = var.test_context.bbd_version_ref != null ? var.test_context.bbd_version_ref : module.meshstack_link[0].building_block_definition.version_ref
}

resource "meshstack_building_block" "this" {
  depends_on          = [module.meshstack_link]
  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = { uuid = local.version_ref.uuid }

    display_name = "smoke-test-link-${var.test_context.name_suffix}"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    # All three inputs (url, title, summary) are STATIC — the platform team supplies them in the
    # building block definition, so ordering passes nothing.
    inputs = {}
  }
}

# Expected values are known only in build-from-source mode, where this test configures the BBD
# itself. In foundation mode the deployed BBD points wherever the foundation pointed it, so these
# are null and the corresponding assertions skip.
output "expected_url" {
  description = "URL the building block under test should surface, or null in foundation mode."
  value       = var.test_context.bbd_version_ref == null ? local.link_url : null
}

output "expected_summary" {
  description = "Markdown summary the building block under test should render, or null in foundation mode."
  value       = var.test_context.bbd_version_ref == null ? local.link_summary : null
}
