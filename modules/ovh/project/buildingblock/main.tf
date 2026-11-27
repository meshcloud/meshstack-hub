data "ovh_me" "this" {}

data "ovh_me_identity_users" "all" {}

data "ovh_me_identity_user" "all" {
  for_each = toset(data.ovh_me_identity_users.all.users)

  user = each.value
}

locals {
  project_description = "${var.workspace_identifier}-${var.project_identifier}"

  # OVHcloud reserves policy names starting with `ovh-`, which a workspace like `ovh-platform` hits.
  policy_name_prefix = "meshstack-${local.project_description}"

  # Users are not created. A member's OVHcloud identity is the existing local user in the `DEFAULT`
  # group named like the part of their email before the `@`; members without one get no access.
  local_user_urns = {
    for login, user in data.ovh_me_identity_user.all : login => user.urn if user.group == "DEFAULT"
  }

  member_logins = { for u in var.users : u.email => split("@", u.email)[0] }

  unknown_members = sort([
    for email, login in local.member_logins : email if !contains(keys(local.local_user_urns), login)
  ])

  role_identities = {
    for role in keys(var.role_mapping) : role => sort(distinct([
      for u in var.users : local.local_user_urns[local.member_logins[u.email]]
      if contains(u.roles, role) && contains(keys(local.local_user_urns), local.member_logins[u.email])
    ]))
  }

  # An IAM policy needs at least one identity.
  role_policies = { for role, identities in local.role_identities : role => identities if length(identities) > 0 }
}

data "ovh_order_cart" "this" {
  ovh_subsidiary = data.ovh_me.this.ovh_subsidiary
}

data "ovh_order_cart_product_plan" "project" {
  cart_id        = data.ovh_order_cart.this.id
  price_capacity = "renew"
  product        = "cloud"
  plan_code      = "project.2018"
}

resource "ovh_cloud_project" "this" {
  ovh_subsidiary = data.ovh_order_cart.this.ovh_subsidiary
  description    = local.project_description

  plan {
    duration     = data.ovh_order_cart_product_plan.project.selected_price[0].duration
    pricing_mode = data.ovh_order_cart_product_plan.project.selected_price[0].pricing_mode
    plan_code    = data.ovh_order_cart_product_plan.project.plan_code
  }
}

resource "ovh_iam_policy" "role" {
  for_each = local.role_policies

  name        = "${local.policy_name_prefix}-${each.key}"
  description = "meshStack role ${each.key} on Public Cloud project ${local.project_description}"
  identities  = each.value
  resources   = [ovh_cloud_project.this.urn]
  allow       = var.role_mapping[each.key]
}
