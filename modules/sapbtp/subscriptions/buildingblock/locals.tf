locals {
  raw_subscriptions = var.subscriptions != "" ? (
    can(jsondecode(var.subscriptions)) ? jsondecode(var.subscriptions) : split(",", var.subscriptions)
  ) : []

  parsed_subscriptions = [
    for s in local.raw_subscriptions :
    {
      app_name   = split(".", trimspace(s))[0]
      plan_name  = split(".", trimspace(s))[1]
      parameters = {}
    }
    if trimspace(s) != ""
  ]

  subscriptions_map = {
    for idx, subscription in local.parsed_subscriptions :
    "${subscription.app_name}-${subscription.plan_name}" => subscription
  }
}
