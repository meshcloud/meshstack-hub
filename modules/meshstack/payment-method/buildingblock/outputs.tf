output "payment_method_name" {
  # Returns the name if created, or null if count was 0
  value       = one(meshstack_payment_method.payment_method[*].metadata.name)
  description = "The name of the payment method"
}

output "workspace_id" {
  value       = one(meshstack_payment_method.payment_method[*].metadata.owned_by_workspace)
  description = "The workspace ID associated with this payment method"
}

output "amount" {
  value       = one(meshstack_payment_method.payment_method[*].spec.amount)
  description = "The budget amount for this payment method"
}
