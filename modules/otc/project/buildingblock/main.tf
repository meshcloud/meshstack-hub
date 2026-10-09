locals {
  otc_project_name = "${var.region}_${var.project_name}"

  groups = {
    for role in keys(var.role_mapping) : role => "${local.otc_project_name}_${role}"
  }

  group_role_assignments = {
    for a in flatten([
      for role, otc_roles in var.role_mapping : [
        for otc_role in otc_roles : { key = "${role}:${otc_role}", role = role, otc_role = otc_role }
      ]
    ]) : a.key => a
  }

  # Who belongs in which group. Federation computes group membership at every sign-in from the
  # identity provider's mapping, so this record is the only place membership lives — there is no
  # group membership to replicate.
  membership = {
    for role, group in local.groups : group => sort([for u in var.users : u.email if contains(u.roles, role)])
  }

  # Without federation, existing local IAM users are put into the groups instead. IAM usernames
  # cannot contain an `@`, and the provider looks users up by name only, so a member's IAM user is
  # the one named like the part of their email before the `@`.
  local_users_enabled = var.mapping_bucket == null

  local_user_names = local.local_users_enabled ? {
    for u in var.users : u.email => split("@", u.email)[0]
  } : {}

  local_group_members = {
    for role, group in local.groups : role => sort(distinct([
      for u in var.users : local.local_user_names[u.email] if contains(u.roles, role)
    ]))
    if local.local_users_enabled && anytrue([for u in var.users : contains(u.roles, role)])
  }
}

data "opentelekomcloud_identity_project_v3" "region" {
  name = var.region
}

data "opentelekomcloud_identity_role_v3" "this" {
  for_each = toset(flatten(values(var.role_mapping)))

  name = each.value
}

resource "opentelekomcloud_identity_project_v3" "this" {
  name        = local.otc_project_name
  parent_id   = data.opentelekomcloud_identity_project_v3.region.id
  description = "Managed by meshStack."
}

resource "opentelekomcloud_identity_group_v3" "this" {
  for_each = local.groups

  name        = each.value
  description = "meshStack ${each.key} of ${local.otc_project_name}."
}

resource "opentelekomcloud_identity_role_assignment_v3" "this" {
  for_each = local.group_role_assignments

  group_id   = opentelekomcloud_identity_group_v3.this[each.value.role].id
  project_id = opentelekomcloud_identity_project_v3.this.id
  role_id    = data.opentelekomcloud_identity_role_v3.this[each.value.otc_role].id
}

# The identity provider has a single mapping that every project shares, so no project writes it.
# Each one records its own membership as one object in the mapping bucket, which no other project
# touches, and the backplane's aggregator function rebuilds the whole mapping from all of them.
resource "opentelekomcloud_obs_bucket_object" "membership" {
  lifecycle {
    enabled = var.mapping_bucket != null
  }

  bucket       = var.mapping_bucket
  key          = "mappings/${local.otc_project_name}.json"
  content_type = "application/json"
  content = jsonencode({
    project = local.otc_project_name
    groups  = local.membership
  })

  depends_on = [opentelekomcloud_identity_group_v3.this]
}

# A member without a matching IAM user fails the lookup, and with it the run, naming the user that is
# missing. Creating that user in T Cloud Public and re-running is the fix; meshStack creates none.
data "opentelekomcloud_identity_user_v3" "member" {
  for_each = toset(values(local.local_user_names))

  name = each.value
}

resource "opentelekomcloud_identity_group_membership_v3" "local" {
  for_each = local.local_group_members

  group = opentelekomcloud_identity_group_v3.this[each.key].id
  users = [for name in each.value : data.opentelekomcloud_identity_user_v3.member[name].id]
}
