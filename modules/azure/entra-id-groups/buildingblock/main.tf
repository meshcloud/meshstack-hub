locals {
  roles      = [for r in split(",", var.project_roles) : trimspace(r) if trimspace(r) != ""]
  au_id      = var.administrative_unit_id != "" ? var.administrative_unit_id : null
  name_parts = compact([var.prefix, var.workspace_identifier, var.project_identifier])

  # Without roles there is one group, keyed "members", that takes every member whatever their role.
  # This is what a workspace-level building block gets, where the roles are the workspace roles.
  default_groups = length(local.roles) > 0 ? {
    for role in local.roles : role => { display_name = join(".", concat(local.name_parts, [role])), roles = tolist([role]) }
  } : { members = { display_name = join(".", local.name_parts), roles = null } }

  groups = var.groups == null ? local.default_groups : {
    for key, group in var.groups : key => {
      display_name = replace(replace(group.name, "{workspace}", var.workspace_identifier), "{project}", var.project_identifier)
      roles        = group.roles
    }
  }

  # Earlier versions keyed the members of the single default group by euid alone. Keeping that key
  # lets an upgrade leave existing memberships in place: azuread refuses to create one that exists.
  single_default_group = var.groups == null && length(local.roles) == 0

  group_memberships = merge([
    for key, group in local.groups : {
      for user in var.users :
      (local.single_default_group ? user.euid : "${user.euid}-${key}") => { euid = user.euid, group = key }
      if group.roles == null || length(setintersection(group.roles, user.roles)) > 0
    }
  ]...)

  unique_user_euids = toset([for membership in values(local.group_memberships) : membership.euid])
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
  # `try` because the lookup has no instance at all when there is no member to resolve, and
  # `members[0]` then does not exist.
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
  for_each = local.groups

  display_name            = each.value.display_name
  security_enabled        = true
  mail_enabled            = false
  administrative_unit_ids = local.au_id != null ? [local.au_id] : []
}

resource "azuread_group_member" "project_role" {
  for_each = {
    for key, membership in local.group_memberships : key => membership
    if contains(keys(local.lookup_values), lower(membership.euid))
  }

  group_object_id  = azuread_group.project_role[each.value.group].object_id
  member_object_id = local.lookup_values[lower(each.value.euid)]
}
