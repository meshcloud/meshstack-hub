variable "test_context" {
  type = object({
    # Receives the ordered building blocks.
    workspace = string

    # Owns the definitions, when that is not `workspace`. Only a released version can be ordered
    # from another workspace: a draft is visible to its owner alone.
    definition_workspace = optional(string)

    # Must match the `hub.bbd_draft` the definitions were deployed with: a draft has no released
    # version to order against.
    bbd_draft = bool
  })
  nullable = false
}

data "meshstack_building_block_definitions" "published" {
  workspace_identifier = coalesce(var.test_context.definition_workspace, var.test_context.workspace)
}

locals {
  # The defaults of `spec.display_name` in the two modules' meshstack_integration.tf. A deployment
  # that renamed its definitions has to say so here.
  display_names = {
    service_account = "STACKIT Service Account"
    federation      = "STACKIT Service Account Federation"
  }

  definitions = {
    for key, display_name in local.display_names : key => one([
      for definition in data.meshstack_building_block_definitions.published.building_block_definitions
      : definition if definition.spec.display_name == display_name
    ])
  }

  # `try` because a definition is null until the foundation has published it, and reading an
  # attribute of null faults before the preconditions below can say that in plain words.
  versions = {
    for key, definition in local.definitions : key => (
      var.test_context.bbd_draft ? try(definition.version_latest, null) : try(definition.version_latest_release, null)
    )
  }
}

output "service_account_version_ref" {
  # `try` for the same reason: a missing definition or version has to reach its precondition.
  value = { uuid = try(local.versions.service_account.uuid, "") }

  precondition {
    condition     = local.versions.service_account != null
    error_message = "No ${var.test_context.bbd_draft ? "" : "released "}version of a building block definition named '${local.display_names.service_account}' owned by workspace '${data.meshstack_building_block_definitions.published.workspace_identifier}'. Deploy it before smoke testing it, with the `hub.bbd_draft` that test_context.bbd_draft says."
  }
}

output "version_ref" {
  # `try` for the same reason: a missing definition or version has to reach its precondition.
  value = { uuid = try(local.versions.federation.uuid, "") }

  precondition {
    condition     = local.versions.federation != null
    error_message = "No ${var.test_context.bbd_draft ? "" : "released "}version of a building block definition named '${local.display_names.federation}' owned by workspace '${data.meshstack_building_block_definitions.published.workspace_identifier}'. Deploy it before smoke testing it, with the `hub.bbd_draft` that test_context.bbd_draft says."
  }
}

output "definition_uuid" {
  # `try` for the same reason; the precondition on `version_ref` names the miss.
  value = try(local.definitions.federation.metadata.uuid, "")
}
