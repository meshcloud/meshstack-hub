resource "btp_subaccount_entitlement" "entitlement_with_quota" {
  for_each = local.entitlements_map_with_quota

  subaccount_id = var.subaccount_id
  service_name  = each.value.service_name
  plan_name     = each.value.plan_name
  amount        = each.value.amount

  lifecycle {
    ignore_changes = [amount]
  }
}

resource "btp_subaccount_entitlement" "entitlement_without_quota" {
  for_each = local.entitlements_map_without_quota

  subaccount_id = var.subaccount_id
  service_name  = each.value.service_name
  plan_name     = each.value.plan_name
}
