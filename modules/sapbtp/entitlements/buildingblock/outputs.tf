output "entitlements" {
  description = "Map of entitlements created for this subaccount"
  value = merge(
    {
      for k, v in btp_subaccount_entitlement.entitlement_with_quota :
      k => {
        service_name = v.service_name
        plan_name    = v.plan_name
        amount       = v.amount
      }
    },
    {
      for k, v in btp_subaccount_entitlement.entitlement_without_quota :
      k => {
        service_name = v.service_name
        plan_name    = v.plan_name
        amount       = null
      }
    }
  )
}

output "subaccount_id" {
  description = "The subaccount ID (passthrough for dependency chaining)"
  value       = var.subaccount_id
}
