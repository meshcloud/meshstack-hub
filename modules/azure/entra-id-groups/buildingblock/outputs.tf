output "group_object_ids" {
  description = "Map of project role name to Entra group object ID."
  value       = { for role, g in azuread_group.project_role : role => g.object_id }
}

output "group_display_names" {
  description = "Map of project role name to Entra group display name."
  value       = { for role, g in azuread_group.project_role : role => g.display_name }
}
