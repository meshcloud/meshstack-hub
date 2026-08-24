locals {
  roles      = [for r in split(",", var.project_roles) : trimspace(r) if trimspace(r) != ""]
  au_id      = var.administrative_unit_id != "" ? var.administrative_unit_id : null
  name_parts = compact([var.prefix, var.workspace_identifier, var.project_identifier])

  unique_user_euids = toset([for user in var.users : user.euid])

  user_role_assignments = {
    for pair in flatten([
      for user in var.users : [
        for role in user.roles : {
          key  = "${user.euid}-${role}"
          euid = user.euid
          role = role
        }
      ]
    ]) : pair.key => pair
    if contains(local.roles, pair.role)
  }
}

# One bulk lookup with ignore_missing, rather than a data source per member: a project member who
# has no object in the directory (external collaborator, service account, a guest that was never
# invited) must not fail the whole building block. Unresolved members are reported through the
# unresolved_users output and the run summary instead of aborting the run.
data "azuread_users" "members" {
  count = length(local.unique_user_euids) > 0 ? 1 : 0

  ignore_missing = true

  mails                = var.user_lookup_attribute == "email" ? sort(tolist(local.unique_user_euids)) : null
  user_principal_names = var.user_lookup_attribute == "upn" ? sort(tolist(local.unique_user_euids)) : null
}

locals {
  lookup_values = {
    for u in try(data.azuread_users.members[0].users, []) :
    lower(coalesce(var.user_lookup_attribute == "email" ? u.mail : u.user_principal_name, "")) => u.object_id
    if coalesce(var.user_lookup_attribute == "email" ? u.mail : u.user_principal_name, "") != ""
  }

  # Directory lookups are case-insensitive, so match on a lowercased key to avoid treating a
  # member whose meshStack euid differs only in case from the directory value as unresolved.
  unresolved_user_euids = sort([
    for euid in local.unique_user_euids : euid
    if !contains(keys(local.lookup_values), lower(euid))
  ])
}

resource "azuread_group" "project_role" {
  for_each = toset(local.roles)

  display_name            = join(".", concat(local.name_parts, [each.value]))
  security_enabled        = true
  mail_enabled            = false
  administrative_unit_ids = local.au_id != null ? [local.au_id] : []
}

resource "azuread_group_member" "project_role" {
  for_each = {
    for key, assignment in local.user_role_assignments : key => assignment
    if contains(keys(local.lookup_values), lower(assignment.euid))
  }

  group_object_id  = azuread_group.project_role[each.value.role].object_id
  member_object_id = local.lookup_values[lower(each.value.euid)]
}
