output "payment_method_id" {
  value       = meshstack_payment_method.payment_method.id
  description = "The ID of the created payment method"
}

output "payment_method_name" {
  value       = meshstack_payment_method.payment_method.name
  description = "The name of the payment method"
}

output "workspace_id" {
  value       = meshstack_payment_method.payment_method.workspace_id
  description = "The workspace ID associated with this payment method"
}

output "amount" {
  value       = meshstack_payment_method.payment_method.amount
  description = "The budget amount for this payment method"
}
