output "subscriptions" {
  description = "Map of application subscriptions created in this subaccount"
  value = {
    for k, v in btp_subaccount_subscription.subscription :
    k => {
      app_name  = v.app_name
      plan_name = v.plan_name
      state     = v.state
    }
  }
}

output "subaccount_id" {
  description = "The subaccount ID (passthrough for dependency chaining)"
  value       = var.subaccount_id
}
