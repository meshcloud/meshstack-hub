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

data "azuread_user" "by_upn" {
  for_each            = var.user_lookup_attribute == "upn" ? local.unique_user_euids : toset([])
  user_principal_name = each.value
}

data "azuread_user" "by_email" {
  for_each = var.user_lookup_attribute == "email" ? local.unique_user_euids : toset([])
  mail     = each.value
}

resource "azuread_group" "project_role" {
  for_each = toset(local.roles)

  display_name            = join(".", concat(local.name_parts, [each.value]))
  security_enabled        = true
  mail_enabled            = false
  administrative_unit_ids = local.au_id != null ? [local.au_id] : []
}

resource "azuread_group_member" "project_role" {
  for_each = local.user_role_assignments

  group_object_id  = azuread_group.project_role[each.value.role].object_id
  member_object_id = var.user_lookup_attribute == "upn" ? data.azuread_user.by_upn[each.value.euid].object_id : data.azuread_user.by_email[each.value.euid].object_id
}
