locals {
  roles          = [for r in split(",", var.project_roles) : trimspace(r) if trimspace(r) != ""]
  au_id          = var.administrative_unit_id != "" ? var.administrative_unit_id : null
  name_parts     = compact([var.prefix, var.workspace_identifier, var.project_identifier])
}

resource "azuread_group" "project_role" {
  for_each = toset(local.roles)

  display_name     = join("-", concat(local.name_parts, [each.value]))
  security_enabled = true
  mail_enabled     = false
}

resource "azuread_administrative_unit_member" "project_role" {
  for_each = local.au_id != null ? toset(local.roles) : toset([])

  administrative_unit_object_id = local.au_id
  member_object_id              = azuread_group.project_role[each.value].object_id
}
