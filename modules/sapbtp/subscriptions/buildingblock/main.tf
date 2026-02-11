resource "btp_subaccount_subscription" "subscription" {
  for_each = local.subscriptions_map

  subaccount_id = var.subaccount_id
  app_name      = each.value.app_name
  plan_name     = each.value.plan_name
  parameters    = jsonencode(each.value.parameters)
}
