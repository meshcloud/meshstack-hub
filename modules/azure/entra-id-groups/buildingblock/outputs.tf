output "group_object_ids" {
  description = "Map of project role name to Entra group object ID; the single group is keyed \"members\"."
  value       = { for role, g in azuread_group.project_role : role => g.object_id }
}

output "group_display_names" {
  description = "Map of project role name to Entra group display name; the single group is keyed \"members\"."
  value       = { for role, g in azuread_group.project_role : role => g.display_name }
}

output "unresolved_users" {
  description = "Members that have no matching object in the directory and were therefore not added to any group."
  value       = local.unresolved_user_euids
}

# Assembled line by line rather than with template directives: a %{for} body keeps its source
# indentation, and four leading spaces turn a table row or list item into a markdown code block.
locals {
  summary_group_rows = [
    for role, g in azuread_group.project_role : "| `${role}` | `${g.display_name}` |"
  ]

  summary_unresolved_section = length(local.unresolved_user_euids) == 0 ? [] : concat(
    [
      "",
      "## ⚠️ Unresolved members",
      "",
      "The following ${length(local.unresolved_user_euids)} member(s) have no object in this directory and were **not** added to any group:",
      "",
    ],
    [for euid in local.unresolved_user_euids : "- `${euid}`"],
    [
      "",
      "Their meshStack roles are unaffected, but they will not inherit any access granted through these groups. Add them to the directory, or check that the lookup attribute matches how they are represented there.",
    ]
  )
}

output "summary" {
  description = "Markdown summary of the created groups and of any members that could not be resolved."
  value = join("\n", concat(
    [
      "# Entra ID Groups",
      "",
      var.project_identifier == "" ? "${length(local.group_display_names)} security group(s) for workspace `${var.workspace_identifier}`." : "${length(local.group_display_names)} security group(s) for project `${var.project_identifier}` in workspace `${var.workspace_identifier}`.",
      "",
      "| Role | Entra group |",
      "|---|---|",
    ],
    local.summary_group_rows,
    [
      "",
      "${length(azuread_group_member.project_role)} group membership(s) assigned from ${length(local.unique_user_euids)} member(s), matched on the `${var.user_lookup_attribute}` attribute.",
    ],
    local.summary_unresolved_section
  ))
}
