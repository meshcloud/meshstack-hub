output "payment_method_name" {
  value       = meshstack_payment_method.payment_method.metadata.name
  description = "The name of the payment method"
}

output "workspace_id" {
  value       = meshstack_payment_method.payment_method.metadata.owned_by_workspace
  description = "The workspace ID associated with this payment method"
}

output "amount" {
  value       = meshstack_payment_method.payment_method.spec.amount
  description = "The budget amount for this payment method"
}
