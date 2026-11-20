variables {
  configured_groups = true
}

run "azure_entra_id_groups_configured_groups" {
  assert {
    condition     = meshstack_building_block.this.status.succeeded
    error_message = "azure/entra-id-groups building block with configured groups expected SUCCEEDED, got health status ${meshstack_building_block.this.status.health_status}, action ${meshstack_building_block.this.status.action}"
  }

  assert {
    condition = length(regexall(
      "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}",
      meshstack_building_block.this.status.outputs["group_object_ids"].value
    )) == 2
    error_message = "expected group_object_ids to contain exactly 2 Entra group object IDs (everyone, nobody), got ${meshstack_building_block.this.status.outputs["group_object_ids"].value}"
  }

  # A name without "{workspace}" or "{project}" left in it proves both were replaced by the run.
  assert {
    condition = alltrue([
      can(regex("hub-e2e-[^\"]*[.]everyone", meshstack_building_block.this.status.outputs["group_display_names"].value)),
      can(regex("hub-e2e-[^\"]*[.]nobody", meshstack_building_block.this.status.outputs["group_display_names"].value)),
      !can(regex("[{](workspace|project)[}]", meshstack_building_block.this.status.outputs["group_display_names"].value)),
    ])
    error_message = "expected group_display_names to hold the configured names with the identifiers filled in, got ${meshstack_building_block.this.status.outputs["group_display_names"].value}"
  }

  # Member rows read "| <name> | `<euid>` | `<group>` |", and an euid is an e-mail address, so the
  # group table rows, keyed by group key, never match. Every member lands in "everyone" and none
  # in "nobody", whose role nobody holds.
  assert {
    condition = alltrue([
      can(regex("@[^`]*` [|] `hub-e2e-[^`]*[.]everyone` [|]", meshstack_building_block.this.status.outputs["summary"].value)),
      !can(regex("@[^`]*` [|] `hub-e2e-[^`]*[.]nobody` [|]", meshstack_building_block.this.status.outputs["summary"].value)),
    ])
    error_message = "expected members in the everyone group and none in the nobody group, got ${meshstack_building_block.this.status.outputs["summary"].value}"
  }
}
