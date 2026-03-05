output "payment_method_name" {
  value       = var.payment_method_name
  description = "The name of the payment method"
}

output "workspace_id" {
  value       = var.workspace_id
  description = "The workspace ID associated with this payment method"
}

output "amount" {
  value       = var.amount
  description = "The budget amount for this payment method"
}

output "summary" {
  value = <<EOT
- **Approval status**: ${var.approval ? "The payment method request was approved." : "The payment method request was **rejected**."}
EOT
}