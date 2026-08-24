run "azure_entra_id_groups_hub" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "azure/entra-id-groups hub building block expected SUCCEEDED, got ${meshstack_building_block.this.status.status}"
  }

  # group_object_ids is a role -> object ID map serialised into a STRING output. Counting GUIDs in
  # the raw value asserts "three real Entra groups were created" without depending on whether the
  # runner single- or double-encodes a map-valued STRING output.
  assert {
    condition = length(regexall(
      "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}",
      meshstack_building_block.this.status.outputs["group_object_ids"].value
    )) == 3
    error_message = "expected group_object_ids to contain exactly 3 Entra group object IDs (admin, user, reader), got ${meshstack_building_block.this.status.outputs["group_object_ids"].value}"
  }

  # Group display names are "<prefix>.<workspace>.<project>.<role>", so each configured role must
  # appear as a dot-suffixed segment. This proves the naming convention held end to end.
  assert {
    condition = alltrue([
      for role in ["admin", "user", "reader"] :
      can(regex("[.]${role}", meshstack_building_block.this.status.outputs["group_display_names"].value))
    ])
    error_message = "expected group_display_names to contain a '.admin', '.user' and '.reader' suffixed group, got ${meshstack_building_block.this.status.outputs["group_display_names"].value}"
  }

  # The prefix input is what makes the group names unique per run; assert it actually landed in the
  # generated names rather than being dropped somewhere in the input plumbing.
  assert {
    condition     = can(regex("hub-e2e-", meshstack_building_block.this.status.outputs["group_display_names"].value))
    error_message = "expected group_display_names to carry the 'hub-e2e-<suffix>' prefix, got ${meshstack_building_block.this.status.outputs["group_display_names"].value}"
  }

  # Every member of the fixtures project is a guest in the test tenant, so an "email" lookup must
  # resolve all of them. A non-empty list here means the lookup attribute is wrong for this
  # directory — the run still succeeds by design, so only this assertion catches it.
  assert {
    condition     = length(regexall("@", meshstack_building_block.this.status.outputs["unresolved_users"].value)) == 0
    error_message = "expected every project member to resolve by email, but unresolved_users was ${meshstack_building_block.this.status.outputs["unresolved_users"].value}"
  }

  # The summary is what a platform team reads after a run; assert the groups table rendered and that
  # no unresolved-members warning was emitted.
  assert {
    condition = alltrue([
      can(regex("Entra ID Groups", meshstack_building_block.this.status.outputs["summary"].value)),
      !can(regex("Unresolved members", meshstack_building_block.this.status.outputs["summary"].value)),
    ])
    error_message = "expected the summary to render the group table without an unresolved-members warning, got ${meshstack_building_block.this.status.outputs["summary"].value}"
  }
}
